package com.smartfinance.core.di

import com.smartfinance.core.network.SupabaseClientProvider
import com.smartfinance.data.onboarding.OnboardingRemoteDataSource
import com.smartfinance.data.onboarding.OnboardingRepository
import com.smartfinance.data.onboarding.SupabasePlanAdapter
import com.smartfinance.domain.onboarding.OnboardingApplicationService
import com.smartfinance.domain.onboarding.OnboardingFacade
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideSupabaseClient(): SupabaseClient {
        return SupabaseClientProvider.create()
    }

    @Provides
    @Singleton
    fun provideOnboardingRemoteDataSource(
        supabaseClient: SupabaseClient
    ): OnboardingRemoteDataSource {
        return OnboardingRemoteDataSource(supabaseClient)
    }

    @Provides
    @Singleton
    fun provideOnboardingRepository(
        remoteDataSource: OnboardingRemoteDataSource
    ): OnboardingRepository {
        return SupabasePlanAdapter(remoteDataSource)
    }

    @Provides
    @Singleton
    fun provideOnboardingFacade(
        repository: OnboardingRepository
    ): OnboardingFacade {
        return OnboardingFacade(repository)
    }

    @Provides
    @Singleton
    fun provideOnboardingApplicationService(
        facade: OnboardingFacade
    ): OnboardingApplicationService {
        return OnboardingApplicationService(facade)
    }
}
