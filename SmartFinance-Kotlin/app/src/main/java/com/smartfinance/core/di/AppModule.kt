package com.smartfinance.core.di

import com.smartfinance.core.network.SupabaseClientProvider
import com.smartfinance.data.expenses.ExpenseRemoteDataSource
import com.smartfinance.data.expenses.ExpenseRepository
import com.smartfinance.data.expenses.SupabaseExpenseAdapter
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.data.insights.ComparativeInsightMemoryCache
import com.smartfinance.data.insights.ComparativeInsightRemoteDataSource
import com.smartfinance.data.insights.ComparativeInsightRepository
import com.smartfinance.data.insights.SupabaseComparativeInsightAdapter
import com.smartfinance.data.location_context.LocationContextPreferenceStore
import com.smartfinance.data.location_context.LocationContextRemoteDataSource
import com.smartfinance.data.location_context.LocationContextRepository
import com.smartfinance.data.location_context.SupabaseLocationContextAdapter
import com.smartfinance.data.onboarding.OnboardingRemoteDataSource
import com.smartfinance.data.onboarding.OnboardingRepository
import com.smartfinance.data.onboarding.SupabasePlanAdapter
import com.smartfinance.data.register.RegisterRemoteDataSource
import com.smartfinance.data.register.RegisterRepository
import com.smartfinance.data.register.SupabaseRegisterAdapter
import com.smartfinance.data.signin.SignInRepository
import com.smartfinance.data.signin.SupabaseSignInAdapter
import com.smartfinance.domain.insights.ComparativeInsightApplicationService
import com.smartfinance.domain.expenses.ExpenseApplicationService
import com.smartfinance.domain.location_context.LocationContextApplicationService
import com.smartfinance.domain.onboarding.OnboardingApplicationService
import com.smartfinance.domain.onboarding.OnboardingFacade
import com.smartfinance.domain.register.RegisterApplicationService
import com.smartfinance.domain.register.RegisterFacade
import com.smartfinance.data.plan_insights.BqRepository
import com.smartfinance.data.plan_insights.BqRepositoryImpl
import com.smartfinance.domain.plan_insights.PlanInsightsApplicationService
import com.smartfinance.domain.plan_insights.PlanInsightsFacade
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

    @Provides
    @Singleton
    fun provideExpenseRemoteDataSource(
        supabaseClient: SupabaseClient
    ): ExpenseRemoteDataSource {
        return ExpenseRemoteDataSource(supabaseClient)
    }

    @Provides
    @Singleton
    fun provideExpenseRepository(
        remoteDataSource: ExpenseRemoteDataSource,
        localDao: SmartFinanceDao
    ): ExpenseRepository {
        return SupabaseExpenseAdapter(remoteDataSource, localDao)
    }

    @Provides
    @Singleton
    fun provideExpenseApplicationService(
        repository: ExpenseRepository
    ): ExpenseApplicationService {
        return ExpenseApplicationService(repository)
    }

    @Provides
    @Singleton
    fun provideLocationContextRemoteDataSource(
        supabaseClient: SupabaseClient
    ): LocationContextRemoteDataSource {
        return LocationContextRemoteDataSource(supabaseClient)
    }

    @Provides
    @Singleton
    fun provideLocationContextRepository(
        remoteDataSource: LocationContextRemoteDataSource,
        preferenceStore: LocationContextPreferenceStore
    ): LocationContextRepository {
        return SupabaseLocationContextAdapter(remoteDataSource, preferenceStore)
    }

    @Provides
    @Singleton
    fun provideLocationContextApplicationService(
        repository: LocationContextRepository
    ): LocationContextApplicationService {
        return LocationContextApplicationService(repository)
    }

    @Provides
    @Singleton
    fun provideBqRepository(
        repositoryImpl: BqRepositoryImpl
    ): BqRepository {
        return repositoryImpl
    }

    @Provides
    @Singleton
    fun providePlanInsightsFacade(
        repository: BqRepository
    ): PlanInsightsFacade {
        return PlanInsightsFacade(repository)
    }

    @Provides
    @Singleton
    fun providePlanInsightsApplicationService(
        facade: PlanInsightsFacade
    ): PlanInsightsApplicationService {
        return PlanInsightsApplicationService(facade)
    }

    @Provides
    @Singleton
    fun provideComparativeInsightRemoteDataSource(
        supabaseClient: SupabaseClient
    ): ComparativeInsightRemoteDataSource {
        return ComparativeInsightRemoteDataSource(supabaseClient)
    }

    @Provides
    @Singleton
    fun provideComparativeInsightRepository(
        remoteDataSource: ComparativeInsightRemoteDataSource,
        memoryCache: ComparativeInsightMemoryCache,
        localDao: SmartFinanceDao,
        supabaseClient: SupabaseClient
    ): ComparativeInsightRepository {
        return SupabaseComparativeInsightAdapter(
            remoteDataSource = remoteDataSource,
            memoryCache = memoryCache,
            localDao = localDao,
            supabaseClient = supabaseClient
        )
    }

    @Provides
    @Singleton
    fun provideComparativeInsightApplicationService(
        repository: ComparativeInsightRepository
    ): ComparativeInsightApplicationService {
        return ComparativeInsightApplicationService(repository)
    }

}
