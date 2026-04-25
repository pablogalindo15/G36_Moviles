package com.smartfinance.core.network

import com.smartfinance.BuildConfig
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.serializer.KotlinXSerializer
import io.github.jan.supabase.storage.Storage
import kotlinx.serialization.InternalSerializationApi
import kotlinx.serialization.json.Json
import javax.inject.Singleton

@OptIn(InternalSerializationApi::class)
@Singleton
object SupabaseClientProvider {

    private const val SUPABASE_URL = "https://xhtdvklpcscecceusgwt.supabase.co"

    fun create(): SupabaseClient {
        return createSupabaseClient(
            supabaseUrl = SUPABASE_URL,
            supabaseKey = BuildConfig.SUPABASE_ANON_KEY
        ) {
            install(Postgrest)
            install(Auth)
            install(Storage)
            install(Functions)

            defaultSerializer = KotlinXSerializer(Json {
                ignoreUnknownKeys = true
                isLenient = true
                encodeDefaults = true
            })
        }
    }
}
