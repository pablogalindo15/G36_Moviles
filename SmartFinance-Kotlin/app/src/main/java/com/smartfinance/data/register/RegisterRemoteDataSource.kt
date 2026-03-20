package com.smartfinance.data.register

import com.smartfinance.core.model.Profile
import com.smartfinance.domain.register.RegisterUserRequest
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.gotrue.providers.builtin.Email
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.storage.storage
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.UUID

class RegisterRemoteDataSource(
    private val supabaseClient: SupabaseClient
) {

    suspend fun registerUser(request: RegisterUserRequest): String {
        val signedUpUser = supabaseClient.auth.signUpWith(Email) {
            email = request.email.trim()
            password = request.password
            data = buildJsonObject {
                put("full_name", request.fullName.trim())
            }
        }

        val userId = signedUpUser?.id
            ?: supabaseClient.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("No se pudo obtener el userId del usuario registrado")

        var avatarUrl: String? = null

        // Subir la imagen si existe
        request.profileImage?.let { imageBytes ->
            val fileName = "avatar_${userId}_${UUID.randomUUID()}.jpg"
            val bucket = supabaseClient.storage.from("avatars")
            
            try {
                // Subir el archivo al bucket
                bucket.upload(fileName, imageBytes, upsert = true)
                // Obtener la URL pública
                avatarUrl = bucket.publicUrl(fileName)
            } catch (e: Exception) {
                // Si falla la subida de imagen, continuamos sin ella para no bloquear el registro
                e.printStackTrace()
            }
        }

        // Usamos upsert en lugar de insert para evitar el error de "duplicate key"
        supabaseClient.from("profiles").upsert(
            Profile(
                id = userId,
                fullName = request.fullName.trim(),
                avatarUrl = avatarUrl
            )
        )

        return userId
    }
}
