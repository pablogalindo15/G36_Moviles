package com.smartfinance.data.location_context

import com.smartfinance.core.model.LocationContext
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import javax.inject.Inject
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName
import kotlinx.serialization.json.Json

class LocationContextRemoteDataSource @Inject constructor(
    private val supabaseClient: SupabaseClient
) {

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun detectLocationContext(
        latitude: Double,
        longitude: Double,
        countryCode: String? = null
    ): LocationContext {
        val response = supabaseClient.functions.invoke(
            FUNCTION_NAME,
            DetectLocationContextRequest(
                latitude = latitude,
                longitude = longitude,
                countryCode = countryCode
            )
        )
        val payload = json.decodeFromString<DetectLocationContextResponse>(response.bodyAsText())

        payload.error?.let { error ->
            throw IllegalStateException(payload.details?.let { "$error: $it" } ?: error)
        }

        return LocationContext(
            countryCode = payload.countryCode ?: "UNKNOWN",
            currency = payload.currency ?: throw IllegalStateException("Missing currency"),
            inflationRate = payload.inflationRate,
            inflationWarning = payload.inflationWarning
        )
    }

    private companion object {
        const val FUNCTION_NAME = "detect-location-context"
    }
}

@Serializable
private data class DetectLocationContextRequest(
    val latitude: Double,
    val longitude: Double,
    @SerialName("country_code")
    val countryCode: String? = null
)

@Serializable
private data class DetectLocationContextResponse(
    val error: String? = null,
    val details: String? = null,
    @SerialName("country_code")
    val countryCode: String? = null,
    val currency: String? = null,
    @SerialName("inflation_rate")
    val inflationRate: Double? = null,
    @SerialName("inflation_warning")
    val inflationWarning: String? = null
)
