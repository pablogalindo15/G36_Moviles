package com.smartfinance

import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.NavHostFragment
import androidx.navigation.ui.setupWithNavController
import com.smartfinance.databinding.ActivityMainBinding
import com.smartfinance.domain.onboarding.OnboardingFacade
import dagger.hilt.android.AndroidEntryPoint
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.SessionStatus
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    @Inject
    lateinit var supabaseClient: SupabaseClient

    @Inject
    lateinit var onboardingFacade: OnboardingFacade

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val navHostFragment = supportFragmentManager
            .findFragmentById(R.id.nav_host_fragment) as NavHostFragment
        val navController = navHostFragment.navController

        lifecycleScope.launch {
            val sessionStatus = supabaseClient.auth.sessionStatus
                .filter { it !is SessionStatus.LoadingFromStorage }
                .first()

            if (sessionStatus is SessionStatus.Authenticated) {
                val userId = sessionStatus.session.user?.id ?: ""
                
                // Verificamos si ya tiene un plan generado
                val existingPlan = onboardingFacade.fetchGeneratedPlan(userId)
                
                val navGraph = navController.navInflater.inflate(R.navigation.nav_graph)
                
                if (existingPlan != null) {
                    // Si tiene plan, va a Insights
                    navGraph.setStartDestination(R.id.insightsFragment)
                } else {
                    // Si no tiene plan, va a Onboarding
                    navGraph.setStartDestination(R.id.onboardingFragment)
                }
                
                val bundle = Bundle().apply {
                    putString("userId", userId)
                }
                navController.setGraph(navGraph, bundle)
            }
        }

        binding.bottomNav.setupWithNavController(navController)

        val hideNavDestinations = setOf(
            R.id.signInFragment,
            R.id.registerFragment,
            R.id.onboardingFragment,
            R.id.logExpenseFragment
        )
        navController.addOnDestinationChangedListener { _, destination, _ ->
            binding.bottomNav.visibility =
                if (destination.id in hideNavDestinations) View.GONE else View.VISIBLE
        }
    }
}
