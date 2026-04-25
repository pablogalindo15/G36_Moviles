package com.smartfinance.core.location

import android.content.Context
import android.location.Geocoder
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object LocationCountryResolver {

    suspend fun resolve(
        context: Context,
        latitude: Double,
        longitude: Double
    ): String? = withContext(Dispatchers.IO) {
        val geocoderCountry = runCatching {
            if (!Geocoder.isPresent()) return@runCatching null
            Geocoder(context, Locale.ENGLISH)
                .getFromLocation(latitude, longitude, 1)
                ?.firstOrNull()
                ?.countryCode
                ?.uppercase(Locale.US)
        }.getOrNull()

        geocoderCountry?.takeIf { it.isNotBlank() }
            ?: Locale.getDefault().country.takeIf { it.isNotBlank() }?.uppercase(Locale.US)
    }
}
