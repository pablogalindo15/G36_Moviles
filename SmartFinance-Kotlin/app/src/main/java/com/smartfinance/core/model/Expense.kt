package com.smartfinance.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ExpenseInsert(
    @SerialName("user_id") val userId: String,
    val amount: Double,
    val currency: String,
    val category: String,
    val note: String? = null,
    @SerialName("occurred_at") val occurredAt: String,
    @SerialName("client_uuid") val clientUuid: String
)

@Serializable
data class ExpenseRecord(
    val id: String,
    @SerialName("user_id") val userId: String,
    val amount: Double,
    val currency: String,
    val category: String,
    val note: String? = null,
    @SerialName("occurred_at") val occurredAt: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("client_uuid") val clientUuid: String
)
