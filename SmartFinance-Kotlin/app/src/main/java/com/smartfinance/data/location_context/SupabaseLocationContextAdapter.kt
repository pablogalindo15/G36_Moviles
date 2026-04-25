package com.smartfinance.data.location_context

import com.smartfinance.core.model.LocationContext
import javax.inject.Inject

class SupabaseLocationContextAdapter @Inject constructor(
    private val remoteDataSource: LocationContextRemoteDataSource,
    private val preferenceStore: LocationContextPreferenceStore
) : LocationContextRepository {

    override suspend fun detectAndCache(
        latitude: Double,
        longitude: Double,
        countryCode: String?
    ): LocationContext {
        return remoteDataSource.detectLocationContext(latitude, longitude, countryCode).also { context ->
            preferenceStore.save(context)
        }
    }

    override suspend fun getCachedContext(): LocationContext? {
        return preferenceStore.read()
    }

    override suspend fun shouldShowSmartFeaturePopup(): Boolean {
        return preferenceStore.shouldShowSmartFeaturePopup()
    }

    override suspend fun markSmartFeaturePopupShown() {
        preferenceStore.markSmartFeaturePopupShown()
    }
}
