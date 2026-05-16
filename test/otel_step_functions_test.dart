// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_step_functions/otel_step_functions.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_step_functions-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  const smArn = 'arn:aws:states:us-east-1:123:stateMachine:Orders';

  test('StartExecution records CLIENT span', () async {
    await tracedStepFunctionsStartExecution<String>(
      stateMachineArn: smArn,
      executionName: 'exec-1',
      region: 'us-east-1',
      invoke: () async => const StepFunctionsStartResult(
        value: 'ok',
        executionArn: 'arn:aws:states:us-east-1:123:execution:Orders:exec-1',
      ),
    );
    final span = spans.findSpanByName('step_functions start_execution');
    expect(span, isNotNull);
    expect(span!.kind, SpanKind.client);
    final a = attrsOf(span);
    expect(a['rpc.system'], 'aws-api');
    expect(a['rpc.service'], 'StepFunctions');
    expect(a['aws.step_functions.state_machine.arn'], smArn);
    expect(a['aws.step_functions.execution.name'], 'exec-1');
    expect(a['cloud.region'], 'us-east-1');
    expect(
      a['aws.step_functions.execution.arn'],
      'arn:aws:states:us-east-1:123:execution:Orders:exec-1',
    );
  });

  test('state records INTERNAL span', () async {
    await tracedStepFunctionsState<String>(
      stateName: 'ValidateOrder',
      stateType: 'Task',
      executionArn: 'arn:aws:states:us-east-1:123:execution:Orders:exec-2',
      invoke: () async => 'done',
    );
    final span = spans.findSpanByName('state ValidateOrder');
    expect(span, isNotNull);
    expect(span!.kind, SpanKind.internal);
    final a = attrsOf(span);
    expect(a['aws.step_functions.state.name'], 'ValidateOrder');
    expect(a['aws.step_functions.state.type'], 'Task');
  });

  test('records exception', () async {
    await expectLater(
      tracedStepFunctionsStartExecution<String>(
        stateMachineArn: smArn,
        invoke: () async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      spans.findSpanByName('step_functions start_execution')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutStepFunctionsInstrumentationAsync(() async {
      await tracedStepFunctionsStartExecution<String>(
        stateMachineArn: smArn,
        invoke: () async => const StepFunctionsStartResult(value: 'v'),
      );
      await tracedStepFunctionsState<String>(
        stateName: 's',
        stateType: 'Task',
        invoke: () async => 'ok',
      );
    });
    expect(spans.findSpansStartingWith('step_functions '), isEmpty);
    expect(spans.findSpansStartingWith('state '), isEmpty);
  });
}
