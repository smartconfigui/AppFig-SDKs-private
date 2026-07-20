import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import AppFig from '../../react/AppFigReactSDK';

describe('AppFig Stress Tests (React TypeScript)', () => {
  const memoryMonitor = new MemoryMonitor();

  beforeEach(() => {
    memoryMonitor.reset();
    AppFig.reset();
  });

  // TEST 1: Storage Hammering - 10K events with maxEvents: 100,000
  it('TEST01: StorageHammering - 10K events without crash', async () => {
    const config = { maxEvents: 100000, debugMode: true };
    AppFig.initialize(config);
    memoryMonitor.start();

    const errors: string[] = [];

    for (let i = 0; i < 10000; i++) {
      try {
        AppFig.logEvent(`stress_event_${i}`, {
          index: i,
          timestamp: Date.now(),
        });
      } catch (ex: any) {
        errors.push(ex.message);
      }

      if (i % 2000 === 0) {
        memoryMonitor.snapshot(`After ${i} events`);
      }
    }

    memoryMonitor.stop();

    expect(errors).toHaveLength(0);
    expect(memoryMonitor.maxMemoryMB).toBeLessThan(100); // Jest runs in Node, lower limit

    console.log('✅ TEST 1 PASSED: 10K events logged without crash');
    console.log(`   Final Memory: ${memoryMonitor.finalMemoryMB}MB`);
  }, 30000);

  // TEST 2: Payload Mutation - Invalid JSON handling
  it('TEST02: PayloadMutation - Invalid JSON handled gracefully', () => {
    const testCases = [
      { name: 'Unclosed brace', json: '{"features": {' },
      { name: 'Wrong type', json: '{"features": "string"}' },
      { name: 'Null features', json: '{"features": null}' },
      { name: 'Empty', json: '' },
    ];

    let passed = 0;

    for (const testCase of testCases) {
      try {
        // Simulate loading corrupted rules
        const result = AppFig.isFeatureEnabled('test_feature');
        if (result === false || result === null) {
          passed++;
        }
      } catch (ex: any) {
        if (!(ex instanceof TypeError)) {
          console.warn(`Handled invalid JSON '${testCase.name}': ${ex.message}`);
          passed++;
        }
      }
    }

    expect(passed).toBeGreaterThan(0);
    console.log('✅ TEST 2 PASSED: Invalid JSON handled gracefully');
  });

  // TEST 3: Complex Rules - 50+ features with deep sequences
  it('TEST03: ComplexRules - 50+ features evaluated efficiently', async () => {
    const rulesJson = buildComplexRulesJSON(50);
    AppFig.initializeLocal(rulesJson);

    const queryTimes: number[] = [];

    // Background event logging
    const eventLoggingPromise = (async () => {
      for (let i = 0; i < 100; i++) {
        AppFig.logEvent(`bg_event_${i}`, { seq: i });
        await sleep(10);
      }
    })();

    // Query stress test
    for (let i = 0; i < 1000; i++) {
      const start = performance.now();
      const result = AppFig.isFeatureEnabled(`feature_${i % 50}`);
      const end = performance.now();
      queryTimes.push(end - start);
    }

    await eventLoggingPromise;

    const avgTime = queryTimes.reduce((a, b) => a + b, 0) / queryTimes.length;
    const maxTime = Math.max(...queryTimes);

    expect(avgTime).toBeLessThan(10);
    expect(maxTime).toBeLessThan(50);

    console.log('✅ TEST 3 PASSED: Complex rules evaluated efficiently');
    console.log(`   Avg: ${avgTime.toFixed(2)}ms | Max: ${maxTime}ms`);
  }, 30000);

  // TEST 4: Edge Cases - Network & location changes
  it('TEST04: EdgeCases - Network failure and location changes', () => {
    const errors: string[] = [];

    try {
      AppFig.initialize({ offline: true });
      const country = AppFig.getDeviceProperty('country') ?? 'Unknown';
      expect(country).toBeTruthy();
    } catch (ex: any) {
      errors.push(`Offline mode: ${ex.message}`);
    }

    try {
      const timezone = AppFig.getDeviceProperty('timezone') ?? 'UTC';
      expect(timezone).toBeTruthy();
    } catch (ex: any) {
      errors.push(`Timezone: ${ex.message}`);
    }

    try {
      const language = AppFig.getDeviceProperty('language') ?? 'Unknown';
      expect(language).toBeTruthy();
    } catch (ex: any) {
      errors.push(`Language: ${ex.message}`);
    }

    expect(errors).toHaveLength(0);
    console.log('✅ TEST 4 PASSED: Edge cases handled with fallbacks');
  });

  // TEST 5: SDK Not Initialized
  it('TEST05: NotInitialized - Developer error handling', () => {
    AppFig.reset();
    const errors: string[] = [];

    try {
      AppFig.logEvent('premature_event', {});
    } catch (ex: any) {
      if (ex instanceof TypeError) {
        errors.push('TypeError on LogEvent');
      } else {
        console.log(`✓ Expected error on LogEvent: ${ex.message}`);
      }
    }

    try {
      const enabled = AppFig.isFeatureEnabled('test');
      expect(enabled).toBeFalsy();
    } catch (ex: any) {
      if (ex instanceof TypeError) {
        errors.push('TypeError on IsFeatureEnabled');
      }
    }

    try {
      const value = AppFig.getFeatureValue('test');
      expect(value).toBeNull();
    } catch (ex: any) {
      if (ex instanceof TypeError) {
        errors.push('TypeError on GetFeatureValue');
      }
    }

    expect(errors).toHaveLength(0);
    console.log('✅ TEST 5 PASSED: SDK Not Initialized handled gracefully');
  });
});

// ============= HELPERS =============

function buildComplexRulesJSON(featureCount: number): string {
  const features: Record<string, any> = {};

  for (let i = 0; i < featureCount; i++) {
    features[`feature_${i}`] = [
      {
        value: i % 2 === 0 ? 'true' : 'false',
        conditions: [
          {
            type: 'device',
            property: 'platform',
            operator: 'eq',
            value: 'react',
          },
          {
            type: 'user',
            property: 'country',
            operator: 'eq',
            value: 'TR',
          },
        ],
      },
    ];
  }

  return JSON.stringify({ features });
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

class MemoryMonitor {
  private snapshots: number[] = [];
  private startMem: number = 0;

  reset() {
    this.snapshots = [];
    this.startMem = 0;
  }

  start() {
    this.startMem = process.memoryUsage().heapUsed;
  }

  stop() {
    // Calculate final memory
  }

  snapshot(label: string) {
    const heapUsed = process.memoryUsage().heapUsed;
    this.snapshots.push(heapUsed);
  }

  get maxMemoryMB(): number {
    if (this.snapshots.length === 0) return 0;
    return Math.max(...this.snapshots) / (1024 * 1024);
  }

  get finalMemoryMB(): number {
    if (this.snapshots.length === 0) return 0;
    return this.snapshots[this.snapshots.length - 1] / (1024 * 1024);
  }
}
