package com.smartfinance.core.di

import android.content.Context
import androidx.room.Room
import com.smartfinance.data.local.SmartFinanceDao
import com.smartfinance.data.local.SmartFinanceDatabase
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): SmartFinanceDatabase {
        return Room.databaseBuilder(
            context,
            SmartFinanceDatabase::class.java,
            "smart_finance_db"
        ).build()
    }

    @Provides
    fun provideSmartFinanceDao(database: SmartFinanceDatabase): SmartFinanceDao {
        return database.smartFinanceDao()
    }
}
