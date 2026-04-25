package com.smartfinance.domain.location_context

import com.smartfinance.core.model.LocationContext
import com.smartfinance.data.location_context.LocationContextRepository
import javax.inject.Inject

class LocationContextApplicationService @Inject constructor(
    private val repository: LocationContextRepository
) {

    suspend fun detectAndCache(
        latitude: Double,
        longitude: Double,
        countryCode: String? = null
    ): LocationContext {
        return repository.detectAndCache(latitude, longitude, countryCode)
    }

    suspend fun getCachedContext(): LocationContext? {
        return repository.getCachedContext()
    }

    suspend fun shouldShowSmartFeaturePopup(): Boolean {
        return repository.shouldShowSmartFeaturePopup()
    }

    suspend fun markSmartFeaturePopupShown() {
        repository.markSmartFeaturePopupShown()
    }
}
