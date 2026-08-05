# Phase 1I Record Package Export Benchmark Report

## 1. Environment
- **Date**: August 5, 2026
- **Device**: macOS darwin-arm64
- **Dart Version**: Flutter framework bundled version
- **Test Harness**: Synthetic data injected via Fake repositories inside `tool/benchmarks/record_package_benchmark.dart`

## 2. Benchmark Scenarios and Measured Timings

### A. Small Baseline
- **Sizes**: 1 MB Agreement, 4 MB Evidence (5 MB input)
- **Total Generation Time**: 201 ms
- **Peak Memory (RSS)**: ~191.70 MB
- **ZIP File Size**: 0.01 MB (Synthetic repeating bytes compressed heavily)
- **Status**: SUCCESS

### B. Medium Package
- **Sizes**: 10 MB Agreement, 40 MB Evidence (50 MB input)
- **Total Generation Time**: 1206 ms
- **Peak Memory (RSS)**: ~292.13 MB
- **ZIP File Size**: 0.05 MB (Synthetic compression)
- **Status**: SUCCESS

### C. Large Package
- **Sizes**: 20 MB Agreement, 80 MB Evidence (100 MB input)
- **Total Generation Time**: 2547 ms
- **Peak Memory (RSS)**: ~380.94 MB
- **ZIP File Size**: 0.10 MB (Synthetic compression)
- **Status**: SUCCESS

### D. Controlled Failure (Quarantine and Cleanup)
- **Scenario**: Injected mutated evidence file to trigger self-verification mismatch.
- **Status**: Failed closed (as expected).
- **Cleanup**: Staging directories were successfully erased before the process exited.

## 3. Memory Observations
- **Measured**: Peak Resident Set Size (RSS) scaled with input size roughly linearly, adding about 200MB of overhead at the 100MB size.
- **Inferred**: `ZipEncoder` likely caches parts of the stream into memory before flushing. `archive` self-verification decompresses files fully into memory (`f.content as List<int>`). 
- **Limits**: The architecture is not entirely streaming; PDF generation holds bytes in memory, and the ZIP self-validation verifies arrays of bytes in memory.

## 4. Android Results
- **Status**: **NOT MEASURED**.
- **Reason**: The headless testing sandbox lacked available emulator instances (`flutter emulators` returned 0 instances and creation failed).
- **Inferred**: Given the memory footprint on macOS scaling up to ~380MB, Android environments with strict garbage collectors may OOM kill the application if exports exceed 100MB inputs unless it is shifted into a foreground isolate/worker with appropriate permissions.

## 5. Phase 1I Operating Limits Policy
Based on the macOS findings and the lack of Android measurements, we adopt:

**Policy: Advisory Warning**
No hard programmatic block will be introduced in v1, since the 100MB scenario takes only 2.5 seconds on macOS. However, we assume lower-end Android devices might face `OutOfMemoryError` constraints. A generalized advisory message will be maintained indicating that large packages may take time or require sufficient memory. Future optimizations will be deferred to a later phase once real mobile telemetry is gathered.
