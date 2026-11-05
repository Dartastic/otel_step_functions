// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_step_functions_suppression.dart';

const _tracerName = 'dartastic_otel_libs_step_functions';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedStepFunctionsStartExecution` callback.
class StepFunctionsStartResult<T> {
  /// Creates a result.
  const StepFunctionsStartResult({
    required this.value,
    this.executionArn,
  });

  /// The value returned to the caller.
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
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.executionArn != null) {
      span.addAttributes(OTelAPI.attributes([
        OTelAPI.attributeString(
          'aws.step_functions.execution.arn',
          r.executionArn!,
        ),
      ]));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
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
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
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
