// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_step_functions_suppression.dart';

const _tracerName = 'dartastic_otel_libs_step_functions';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedStepFunctionsStartExecution` callback.
class StepFunctionsStartResult<T> {
  const StepFunctionsStartResult({
    required this.value,
    this.executionArn,
  });
  final T value;
  final String? executionArn;
}

/// Wraps a Step Functions `StartExecution` call in a CLIENT span,
/// recording the state-machine ARN, region, execution name.
Future<T> tracedStepFunctionsStartExecution<T>({
  required String stateMachineArn,
  required Future<StepFunctionsStartResult<T>> Function() invoke,
  String? executionName,
  String? region,
}) async {
  if (stepFunctionsInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'aws-api',
    'rpc.service': 'StepFunctions',
    'rpc.method': 'StartExecution',
    'aws.step_functions.state_machine.arn': stateMachineArn,
  };
  if (executionName != null) {
    m['aws.step_functions.execution.name'] = executionName;
  }
  if (region != null) m['cloud.region'] = region;

  final span = _tracer().startSpan(
    'step_functions start_execution',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.executionArn != null) {
      span.addAttributes(OTel.attributes([
        OTel.attributeString(
          'aws.step_functions.execution.arn',
          r.executionArn!,
        ),
      ]));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Wraps the user-side body of one Step Functions state (a Task
/// state, typically a Lambda invocation) in an INTERNAL span so
/// each state shows up as a child of the overall workflow.
Future<T> tracedStepFunctionsState<T>({
  required String stateName,
  required String stateType,
  required Future<T> Function() invoke,
  String? executionArn,
}) async {
  if (stepFunctionsInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'aws.step_functions.state.name': stateName,
    'aws.step_functions.state.type': stateType,
  };
  if (executionArn != null) {
    m['aws.step_functions.execution.arn'] = executionArn;
  }

  final span = _tracer().startSpan(
    'state $stateName',
    kind: SpanKind.internal,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
