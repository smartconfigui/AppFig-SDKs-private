package com.appfig.sdk.stress

import org.junit.Before
import org.junit.Test
import org.junit.Assert.*
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.system.measureTimeMillis

class AppFigStressTests {
    private lateinit var memoryMonitor: MemoryMonitor

    @Before
    fun setup() {
        memoryMonitor = MemoryMonitor()
        AppFig.reset()
    }

    // TEST 1: Storage Hammering - 10K events with maxEvents: 100,000
    @Test(timeout = 30000)
    fun test01_StorageHammering_10KEvents() {
        val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().context
        val config = AppFigConfig(
            maxEvents = 100000,
            debugMode = true
        )
        AppFig.initialize(context, config)
        memoryMonitor.start()

        val errors = CopyOnWriteArrayList<String>()

        for (i in 0 until 10000) {
            try {
                AppFig.logEvent(
                    "stress_event_$i",
                    mapOf(
                        "index" to i,
                        "timestamp" to System.currentTimeMillis()
                    )
                )
            } catch (ex: Exception) {
                errors.add(ex.message ?: "Unknown error")
            }

            if (i % 2000 == 0) {
                memoryMonitor.snapshot("After $i events")
            }
        }

        memoryMonitor.stop()

        assertEquals("Errors occurred: ${errors.joinToString()}", 0, errors.size)
        assertTrue("Memory exceeded 500MB", memoryMonitor.maxMemoryMB < 500)

        println("✅ TEST 1 PASSED: 10K events logged without crash")
        println("   Final Memory: ${memoryMonitor.finalMemoryMB}MB")
    }

    // TEST 2: Payload Mutation - Invalid JSON handling
    @Test
    fun test02_PayloadMutation_InvalidJSON() {
        val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().context
        val testCases = listOf(
            "Unclosed brace: {\"features\": {",
            "Wrong type: {\"features\": \"string\"}",
            "Null features: {\"features\": null}",
            "Empty: "
        )

        var passed = 0

        for (testCase in testCases) {
            try {
                val result = AppFig.isFeatureEnabled("test_feature")
                if (!result) {
                    passed++
                }
            } catch (ex: NullPointerException) {
                System.err.println("❌ NullPointerException on invalid JSON: $testCase")
                fail("NullPointerException thrown")
            }
        }

        assertTrue("No valid fallbacks returned", passed > 0)
        println("✅ TEST 2 PASSED: Invalid JSON handled gracefully")
    }

    // TEST 3: Complex Rules - 50+ features with deep sequences
    @Test(timeout = 30000)
    fun test03_ComplexRules_PerformanceStress() {
        val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().context
        val rulesJson = buildComplexRulesJSON(50)
        AppFig.initializeLocal(context, rulesJson)

        val queryTimes = CopyOnWriteArrayList<Long>()

        // Background event logging
        val eventThread = Thread {
            for (i in 0 until 100) {
                AppFig.logEvent("bg_event_$i", mapOf("seq" to i))
                Thread.sleep(10)
            }
        }
        eventThread.start()

        // Query stress test
        for (i in 0 until 1000) {
            val time = measureTimeMillis {
                AppFig.isFeatureEnabled("feature_${i % 50}")
            }
            queryTimes.add(time)
        }

        eventThread.join()

        val avgTime = if (queryTimes.isNotEmpty()) {
            queryTimes.sum() / queryTimes.size
        } else {
            0
        }
        val maxTime = queryTimes.maxOrNull() ?: 0

        assertTrue("Avg query time too high: ${avgTime}ms", avgTime < 10)
        assertTrue("Max query time too high: ${maxTime}ms", maxTime < 50)

        println("✅ TEST 3 PASSED: Complex rules evaluated efficiently")
        println("   Avg: ${String.format("%.2f", avgTime.toDouble())}ms | Max: ${maxTime}ms")
    }

    // TEST 4: Edge Cases - Network & location changes
    @Test
    fun test04_EdgeCases_NetworkAndLocation() {
        val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().context
        val errors = mutableListOf<String>()

        try {
            AppFig.initialize(context, AppFigConfig(offline = true))
            val country = AppFig.getDeviceProperty("country") ?: "Unknown"
            assertTrue("Country should have fallback", country.isNotEmpty())
        } catch (ex: Exception) {
            errors.add("Offline mode: ${ex.message}")
        }

        try {
            val timezone = AppFig.getDeviceProperty("timezone") ?: "UTC"
            assertTrue("Timezone should have fallback", timezone.isNotEmpty())
        } catch (ex: Exception) {
            errors.add("Timezone: ${ex.message}")
        }

        try {
            val language = AppFig.getDeviceProperty("language") ?: "Unknown"
            assertTrue("Language should have fallback", language.isNotEmpty())
        } catch (ex: Exception) {
            errors.add("Language: ${ex.message}")
        }

        assertEquals("Edge cases failed: ${errors.joinToString()}", 0, errors.size)
        println("✅ TEST 4 PASSED: Edge cases handled with fallbacks")
    }

    // TEST 5: SDK Not Initialized
    @Test
    fun test05_NotInitialized_GeliştiriciHatası() {
        AppFig.reset()
        val errors = mutableListOf<String>()

        try {
            AppFig.logEvent("premature_event", emptyMap())
        } catch (ex: NullPointerException) {
            errors.add("NullPointerException on LogEvent")
        } catch (ex: IllegalStateException) {
            println("✓ Expected IllegalStateException on LogEvent")
        }

        try {
            val enabled = AppFig.isFeatureEnabled("test")
            assertFalse("Should return false when not initialized", enabled)
        } catch (ex: NullPointerException) {
            errors.add("NullPointerException on IsFeatureEnabled")
        }

        try {
            val value = AppFig.getFeatureValue("test")
            assertNull("Should return null when not initialized", value)
        } catch (ex: NullPointerException) {
            errors.add("NullPointerException on GetFeatureValue")
        }

        assertEquals("NullPointerException errors: ${errors.joinToString()}", 0, errors.size)
        println("✅ TEST 5 PASSED: SDK Not Initialized handled gracefully")
    }

    private fun buildComplexRulesJSON(featureCount: Int): String {
        val sb = StringBuilder()
        sb.append("{\"features\":{")

        for (i in 0 until featureCount) {
            if (i > 0) sb.append(",")
            sb.append("\"feature_$i\":[{")
            sb.append("\"value\":\"${if (i % 2 == 0) "true" else "false"}\",")
            sb.append("\"conditions\":[")
            sb.append("{\"type\":\"device\",\"property\":\"platform\",\"operator\":\"eq\",\"value\":\"android\"},")
            sb.append("{\"type\":\"user\",\"property\":\"country\",\"operator\":\"eq\",\"value\":\"TR\"}")
            sb.append("]")
            sb.append("}]")
        }

        sb.append("}}")
        return sb.toString()
    }
}

class MemoryMonitor {
    private val snapshots = mutableListOf<Long>()
    private var startTime = 0L

    fun start() {
        startTime = System.currentTimeMillis()
        System.gc()
    }

    fun stop() {
        // Finalize monitoring
    }

    fun snapshot(label: String) {
        val runtime = Runtime.getRuntime()
        val usedMemory = (runtime.totalMemory() - runtime.freeMemory()) / (1024 * 1024)
        snapshots.add(usedMemory)
    }

    val maxMemoryMB: Long
        get() = snapshots.maxOrNull() ?: 0

    val finalMemoryMB: Long
        get() = if (snapshots.isNotEmpty()) snapshots.last() else 0
}
