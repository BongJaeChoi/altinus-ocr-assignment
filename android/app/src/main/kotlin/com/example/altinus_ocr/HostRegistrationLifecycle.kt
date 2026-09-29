package com.example.altinus_ocr

internal class HostRegistrationLifecycle<Target>(
    private val onRegister: (Target) -> Unit,
    private val onUnregister: (Target) -> Unit,
) {
    private var registeredTarget: Target? = null

    fun register(target: Target) {
        unregister()
        onRegister(target)
        registeredTarget = target
    }

    fun unregister() {
        val target = registeredTarget ?: return
        registeredTarget = null
        onUnregister(target)
    }
}
