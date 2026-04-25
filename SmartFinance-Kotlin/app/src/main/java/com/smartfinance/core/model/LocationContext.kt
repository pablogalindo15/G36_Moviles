package com.smartfinance.core.model

data class LocationContext(
    val countryCode: String,
    val currency: String,
    val inflationRate: Double?,
    val inflationWarning: String?
)
