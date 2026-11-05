// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_step_functions/otel_step_functions.dart';

/// Traces Step Functions `StartExecution` calls with OpenTelemetry.
///
/// `otel_step_functions` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Step Functions `StartExecution` call in
/// [tracedStepFunctionsStartExecution]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'step-functions-example');

  // Wraps a Step Functions StartExecution call in a CLIENT span, recording the state-machine ARN, region, execution name.
  final stepFunctionsStartExecutionId =
      await tracedStepFunctionsStartExecution<String>(
    stateMachineArn: 'active',
    executionName: 'example',
    region: 'us-east-1',
    invoke: () async {
      // Make the Step Functions `StartExecution` call here, then report what it returned.
      const id = 'step_functions_8f3a2c';
      return const StepFunctionsStartResult(value: id, executionArn: 'example');
    },
  );
  OTelLog.info(
      'tracedStepFunctionsStartExecution returned $stepFunctionsStartExecutionId');

  // Traces a Step Functions `StartExecution` call.
  final stepFunctionsStateId = await tracedStepFunctionsState<String>(
    stateName: 'active',
    stateType: 'active',
    executionArn: 'example',
    invoke: () async {
      // Make the Step Functions `StartExecution` call here, then report what it returned.
      return 'step_functions_8f3a2c';
    },
  );
  OTelLog.info('tracedStepFunctionsState returned $stepFunctionsStateId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutStepFunctionsInstrumentationAsync.
  await runWithoutStepFunctionsInstrumentationAsync(
    () => tracedStepFunctionsStartExecution<String>(
      stateMachineArn: 'active',
      executionName: 'example',
      region: 'us-east-1',
      invoke: () async {
        const id = 'step_functions_8f3a2c';
        return const StepFunctionsStartResult(
            value: id, executionArn: 'example');
      },
    ),
  );

  await OTel.shutdown();
}
