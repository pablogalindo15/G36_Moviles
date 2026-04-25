package com.smartfinance.data.location_context

import com.smartfinance.core.model.LocationContext

interface LocationContextRepository {
    suspend fun detectAndCache(
        latitude: Double,
        longitude: Double,
        countryCode: String? = null
    ): LocationContext
    suspend fun getCachedContext(): LocationContext?
    suspend fun shouldShowSmartFeaturePopup(): Boolean
    suspend fun markSmartFeaturePopupShown()
}
