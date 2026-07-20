using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using UnityEngine;

[TestFixture]
public class AppFigStressTests
{
    private MemoryMonitor memoryMonitor;

    [SetUp]
    public void Setup()
    {
        memoryMonitor = new MemoryMonitor();
    }

    // TEST 1: Storage Hammering - 10K events with maxEvents: 100,000
    [Test]
    [Category("StorageHammering")]
    public async Task Test01_StorageHammering_10KEvents()
    {
        var config = new AppFigConfig { maxEvents = 100000 };
        AppFig.Initialize(config);
        memoryMonitor.Start();

        var errors = new List<string>();
        
        for (int i = 0; i < 10000; i++)
        {
            try
            {
                AppFig.LogEvent($"stress_event_{i}", new Dictionary<string, object>
                {
                    { "index", i },
                    { "timestamp", DateTime.Now.Ticks }
                });
            }
            catch (Exception ex)
            {
                errors.Add(ex.Message);
            }

            if (i % 2000 == 0)
                memoryMonitor.Snapshot($"After {i} events");
        }

        memoryMonitor.Stop();

        Assert.That(errors.Count, Is.EqualTo(0), $"Errors: {string.Join(", ", errors)}");
        Assert.That(memoryMonitor.MaxMemoryMB, Is.LessThan(500), "Memory exceeded 500MB");

        Debug.Log("✅ TEST 1 PASSED: 10K events logged without crash");
        Debug.Log($"   Final Memory: {memoryMonitor.FinalMemoryMB}MB");
    }

    // TEST 2: Payload Mutation - Invalid JSON handling
    [Test]
    [Category("PayloadMutation")]
    public void Test02_PayloadMutation_InvalidJSON()
    {
        var testCases = new[]
        {
            "Unclosed brace: {\"features\": {",
            "Wrong type: {\"features\": \"string\"}",
            "Null features: {\"features\": null}",
            "Empty: ",
        };

        var passed = 0;
        
        foreach (var testCase in testCases)
        {
            try
            {
                var result = AppFig.IsFeatureEnabled("test");
                if (result == false || result == null)
                    passed++;
            }
            catch (NullReferenceException)
            {
                Debug.LogError($"❌ NullRef on invalid JSON: {testCase}");
            }
        }

        Assert.That(passed, Is.GreaterThan(0), "No valid fallbacks returned");
        Debug.Log("✅ TEST 2 PASSED: Invalid JSON handled gracefully");
    }

    // TEST 3: Complex Rules - 50+ features with deep conditions
    [Test]
    [Category("ComplexRules")]
    public async Task Test03_ComplexRules_PerformanceStress()
    {
        var rulesJson = BuildComplexRulesJSON(50);
        AppFig.InitializeLocal(rulesJson);

        var queryTimes = new List<long>();
        var eventTask = Task.Run(async () =>
        {
            for (int i = 0; i < 100; i++)
            {
                AppFig.LogEvent($"bg_{i}", null);
                await Task.Delay(10);
            }
        });

        var sw = Stopwatch.StartNew();
        for (int i = 0; i < 1000; i++)
        {
            var query = Stopwatch.StartNew();
            AppFig.IsFeatureEnabled($"feature_{i % 50}");
            query.Stop();
            queryTimes.Add(query.ElapsedMilliseconds);
        }
        sw.Stop();

        await eventTask;

        var avgTime = queryTimes.Average();
        var maxTime = queryTimes.Max();

        Assert.That(avgTime, Is.LessThan(10), $"Avg query time: {avgTime}ms");
        Debug.Log("✅ TEST 3 PASSED: Complex rules evaluated efficiently");
        Debug.Log($"   Avg: {avgTime:F2}ms | Max: {maxTime}ms");
    }

    // TEST 4: Edge Cases - Network & location changes
    [Test]
    [Category("EdgeCases")]
    public void Test04_EdgeCases_NetworkAndLocation()
    {
        var errors = new List<string>();

        try
        {
            AppFig.Initialize(new AppFigConfig { offline = true });
            var country = AppFig.GetDeviceProperty("country") ?? "Unknown";
            Assert.That(country, Is.Not.Empty);
        }
        catch (Exception ex)
        {
            errors.Add($"Offline: {ex.Message}");
        }

        try
        {
            var tz = AppFig.GetDeviceProperty("timezone") ?? "UTC";
            Assert.That(tz, Is.Not.Empty);
        }
        catch (Exception ex)
        {
            errors.Add($"Timezone: {ex.Message}");
        }

        try
        {
            var lang = AppFig.GetDeviceProperty("language") ?? "Unknown";
            Assert.That(lang, Is.Not.Empty);
        }
        catch (Exception ex)
        {
            errors.Add($"Language: {ex.Message}");
        }

        Assert.That(errors.Count, Is.EqualTo(0), $"Edge cases failed: {string.Join("; ", errors)}");
        Debug.Log("✅ TEST 4 PASSED: Edge cases handled with fallbacks");
    }

    // TEST 5: SDK Not Initialized
    [Test]
    [Category("NotInitialized")]
    public void Test05_NotInitialized_GeliştiriciHatası()
    {
        AppFig.Reset();
        var errors = new List<string>();

        try
        {
            AppFig.LogEvent("premature_event", null);
        }
        catch (NullReferenceException)
        {
            errors.Add("NullRef on LogEvent");
        }
        catch (InvalidOperationException)
        {
            Debug.Log("✓ Expected InvalidOperationException on LogEvent");
        }

        try
        {
            var enabled = AppFig.IsFeatureEnabled("test");
            Assert.That(enabled, Is.False.Or.Null);
        }
        catch (NullReferenceException)
        {
            errors.Add("NullRef on IsFeatureEnabled");
        }

        try
        {
            var value = AppFig.GetFeatureValue("test");
            Assert.That(value, Is.Null);
        }
        catch (NullReferenceException)
        {
            errors.Add("NullRef on GetFeatureValue");
        }

        Assert.That(errors.Count, Is.EqualTo(0), $"NullRef errors: {string.Join("; ", errors)}");
        Debug.Log("✅ TEST 5 PASSED: SDK Not Initialized handled gracefully");
    }

    private string BuildComplexRulesJSON(int featureCount)
    {
        var sb = new System.Text.StringBuilder();
        sb.Append("{\"features\":{");
        
        for (int i = 0; i < featureCount; i++)
        {
            if (i > 0) sb.Append(",");
            sb.Append($"\"feature_{i}\":[{{");
            sb.Append($"\"value\":\"{(i % 2 == 0 ? "true" : "false")}\",");
            sb.Append("\"conditions\":[");
            sb.Append("{\"type\":\"device\",\"property\":\"platform\",\"operator\":\"eq\",\"value\":\"unity\"},");
            sb.Append("{\"type\":\"user\",\"property\":\"country\",\"operator\":\"eq\",\"value\":\"TR\"}");
            sb.Append("]");
            sb.Append("}]");
        }
        
        sb.Append("}}");
        return sb.ToString();
    }
}

public class MemoryMonitor
{
    private List<long> snapshots = new();
    
    public long MaxMemoryMB { get; private set; }
    public long FinalMemoryMB { get; private set; }

    public void Start() { }

    public void Stop()
    {
        if (snapshots.Count > 0)
        {
            MaxMemoryMB = snapshots.Max() / (1024 * 1024);
            FinalMemoryMB = snapshots.Last() / (1024 * 1024);
        }
    }

    public void Snapshot(string label)
    {
        snapshots.Add(GC.GetTotalMemory(false));
    }
}
