package com.smartfinance.data.location_context

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.smartfinance.core.model.LocationContext
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.locationContextDataStore by preferencesDataStore(name = "location_context")

@Singleton
class LocationContextPreferenceStore @Inject constructor(
    @ApplicationContext private val context: Context
) {

    suspend fun save(contextValue: LocationContext) {
        context.locationContextDataStore.edit { preferences ->
            preferences[COUNTRY_CODE] = contextValue.countryCode
            preferences[CURRENCY] = contextValue.currency
            preferences[INFLATION_RATE] = contextValue.inflationRate ?: Double.NaN
            preferences[INFLATION_WARNING] = contextValue.inflationWarning.orEmpty()
        }
    }

    suspend fun read(): LocationContext? {
        return preferences().map { preferences ->
            val currency = preferences[CURRENCY] ?: return@map null
            val inflationRate = preferences[INFLATION_RATE]
                ?.takeUnless { it.isNaN() }
            val inflationWarning = preferences[INFLATION_WARNING]
                ?.takeIf { it.isNotBlank() }

            LocationContext(
                countryCode = preferences[COUNTRY_CODE] ?: "UNKNOWN",
                currency = currency,
                inflationRate = inflationRate,
                inflationWarning = inflationWarning
            )
        }.first()
    }

    suspend fun shouldShowSmartFeaturePopup(): Boolean {
        return preferences().map { preferences ->
            !(preferences[SMART_FEATURE_POPUP_SHOWN] ?: false)
        }.first()
    }

    suspend fun markSmartFeaturePopupShown() {
        context.locationContextDataStore.edit { preferences ->
            preferences[SMART_FEATURE_POPUP_SHOWN] = true
        }
    }

    private fun preferences() = context.locationContextDataStore.data
        .catch { error ->
            if (error is IOException) {
                emit(emptyPreferences())
            } else {
                throw error
            }
        }

    private companion object {
        val COUNTRY_CODE = stringPreferencesKey("country_code")
        val CURRENCY = stringPreferencesKey("currency")
        val INFLATION_RATE = doublePreferencesKey("inflation_rate")
        val INFLATION_WARNING = stringPreferencesKey("inflation_warning")
        val SMART_FEATURE_POPUP_SHOWN = booleanPreferencesKey("smart_feature_popup_shown")
    }
}
