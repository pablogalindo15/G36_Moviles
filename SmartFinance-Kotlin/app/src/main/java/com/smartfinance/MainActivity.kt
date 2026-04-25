package com.smartfinance

import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.navigation.fragment.NavHostFragment
import androidx.navigation.ui.setupWithNavController
import com.smartfinance.databinding.ActivityMainBinding
import dagger.hilt.android.AndroidEntryPoint
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    @Inject
    lateinit var supabaseClient: SupabaseClient

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val navHostFragment = supportFragmentManager
            .findFragmentById(R.id.nav_host_fragment) as NavHostFragment
        val navController = navHostFragment.navController

        // Check if user is already logged in
        val session = supabaseClient.auth.currentSessionOrNull()
        if (session != null) {
            val navGraph = navController.navInflater.inflate(R.navigation.nav_graph)
            // If logged in, we go straight to insights (or home)
            navGraph.setStartDestination(R.id.insightsFragment)
            
            // Pass the userId as an argument since fragments expect it
            val bundle = Bundle().apply {
                putString("userId", session.user?.id)
            }
            navController.setGraph(navGraph, bundle)
        }

        binding.bottomNav.setupWithNavController(navController)

        val hideNavDestinations = setOf(R.id.signInFragment, R.id.registerFragment, R.id.onboardingFragment)
        navController.addOnDestinationChangedListener { _, destination, _ ->
            binding.bottomNav.visibility =
                if (destination.id in hideNavDestinations) View.GONE else View.VISIBLE
        }
    }
}
