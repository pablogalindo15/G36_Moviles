package com.smartfinance.core.di

import android.content.Context
import androidx.room.migration.Migration
import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteDatabase
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

    private val migration1To2 = object : Migration(1, 2) {
        override fun migrate(db: SupportSQLiteDatabase) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS local_savings_projection (
                    userId TEXT NOT NULL,
                    isOnTrack INTEGER NOT NULL,
                    projectedSavings REAL NOT NULL,
                    savingsGoal REAL NOT NULL,
                    message TEXT NOT NULL,
                    computedAt INTEGER NOT NULL,
                    cachedAt INTEGER NOT NULL,
                    PRIMARY KEY(userId)
                )
                """.trimIndent()
            )
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS local_comparative_insight (
                    userId TEXT NOT NULL,
                    type TEXT NOT NULL,
                    myWeeklySpending REAL,
                    cohortAverageWeeklySpending REAL,
                    cohortSize INTEGER NOT NULL,
                    percentile REAL,
                    currency TEXT,
                    weekStart TEXT,
                    weekEnd TEXT,
                    reason TEXT,
                    cachedAt INTEGER NOT NULL,
                    PRIMARY KEY(userId)
                )
                """.trimIndent()
            )
        }
    }

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): SmartFinanceDatabase {
        return Room.databaseBuilder(
            context,
            SmartFinanceDatabase::class.java,
            "smart_finance_db"
        )
            .addMigrations(migration1To2)
            .build()
    }

    @Provides
    fun provideSmartFinanceDao(database: SmartFinanceDatabase): SmartFinanceDao {
        return database.smartFinanceDao()
    }
}
