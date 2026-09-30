package dev.bongjae.artinusocr

import org.junit.Assert.assertEquals
import org.junit.Test

class HostRegistrationLifecycleTest {
    @Test
    fun `pairs registration and unregistration across reattach and cleanup`() {
        val events = mutableListOf<String>()
        val lifecycle =
            HostRegistrationLifecycle<String>(
                onRegister = { events += "register:$it" },
                onUnregister = { events += "unregister:$it" },
            )

        lifecycle.register("first")
        lifecycle.register("second")
        lifecycle.unregister()
        lifecycle.unregister()

        assertEquals(
            listOf(
                "register:first",
                "unregister:first",
                "register:second",
                "unregister:second",
            ),
            events,
        )
    }
}
