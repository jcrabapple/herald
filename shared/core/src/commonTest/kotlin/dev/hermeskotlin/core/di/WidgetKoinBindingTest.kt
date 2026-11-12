package dev.hermeskotlin.core.di

import dev.hermeskotlin.core.widget.WidgetRefreshPipelines
import org.koin.core.annotation.KoinInternalApi
import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * Regression witness for the v0.16.1 startup crash: `WidgetRefresher` injects the
 * [WidgetRefreshPipelines] interface, but `coreModule` registered only the concrete
 * `WidgetDataAssembler`, so `get<WidgetRefreshPipelines>()` had no definition and the app died in
 * `Application.onCreate` (Koin "No definition found"). The fix binds the interface.
 *
 * This inspects the module's DEFINITIONS rather than starting Koin: the eager singletons
 * (`AttentionTracker`, `SessionWatcher`) launch coroutines at construction, so a full `startKoin`
 * here would be a teardown race. Reading the definition index needs no instance, no platform module
 * and no Android context, so it stays deterministic on every target. The index is Koin internal API
 * (opted in below); if a Koin upgrade changes it, this test breaks loudly rather than silently.
 */
@OptIn(KoinInternalApi::class)
class WidgetKoinBindingTest {

    @Test
    fun refreshPipelinesInterfaceHasADefinition() {
        val bound = coreModule.mappings.values.any { factory ->
            val definition = factory.beanDefinition
            definition.primaryType == WidgetRefreshPipelines::class ||
                WidgetRefreshPipelines::class in definition.secondaryTypes
        }
        assertTrue(
            bound,
            "coreModule must bind WidgetDataAssembler to WidgetRefreshPipelines " +
                "(single { WidgetDataAssembler(...) } bind WidgetRefreshPipelines::class); " +
                "without it the widgets crash the app at startup",
        )
    }
}