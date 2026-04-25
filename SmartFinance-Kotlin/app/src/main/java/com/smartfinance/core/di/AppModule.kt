package com.smartfinance.core.di

import com.smartfinance.core.network.SupabaseClientProvider
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.data.onboarding.OnboardingRemoteDataSource
import com.smartfinance.data.onboarding.OnboardingRepository
import com.smartfinance.data.onboarding.SupabasePlanAdapter
import com.smartfinance.data.register.RegisterRemoteDataSource
import com.smartfinance.data.register.RegisterRepository
import com.smartfinance.data.register.SupabaseRegisterAdapter
import com.smartfinance.data.signin.SignInRepository
import com.smartfinance.data.signin.SupabaseSignInAdapter
import com.smartfinance.domain.onboarding.OnboardingApplicationService
import com.smartfinance.domain.onboarding.OnboardingFacade
import com.smartfinance.domain.register.RegisterApplicationService
import com.smartfinance.domain.register.RegisterFacade
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
        remoteDataSource: OnboardingRemoteDataSource,
        localDao: SmartFinanceDao
    ): OnboardingRepository {
        return SupabasePlanAdapter(remoteDataSource, localDao)
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


    @Provides
    @Singleton
    fun provideRegisterRemoteDataSource(
        supabaseClient: SupabaseClient
    ): RegisterRemoteDataSource {
        return RegisterRemoteDataSource(supabaseClient)
    }

    @Provides
    @Singleton
    fun provideRegisterRepository(
        remoteDataSource: RegisterRemoteDataSource
    ): RegisterRepository {
        return SupabaseRegisterAdapter(remoteDataSource)
    }

    @Provides
    @Singleton
    fun provideRegisterFacade(
        repository: RegisterRepository
    ): RegisterFacade {
        return RegisterFacade(repository)
    }

    @Provides
    @Singleton
    fun provideRegisterApplicationService(
        facade: RegisterFacade
    ): RegisterApplicationService {
        return RegisterApplicationService(facade)
    }

    @Provides
    fun provideSignInRepository(
        adapter: SupabaseSignInAdapter
    ): SignInRepository = adapter

}
