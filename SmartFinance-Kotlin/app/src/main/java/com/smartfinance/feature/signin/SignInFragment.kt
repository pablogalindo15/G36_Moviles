package com.smartfinance.feature.signin

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import com.smartfinance.core.model.UiState
import com.smartfinance.databinding.FragmentSigninBinding
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import com.smartfinance.R


@AndroidEntryPoint
class SignInFragment : Fragment() {

    private var _binding: FragmentSigninBinding? = null
    private val binding get() = _binding!!

    private val viewModel: SignInViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentSigninBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        setupUI()
        observeState()
    }

    private fun setupUI() {
        binding.btnSignIn.setOnClickListener {
            val email = binding.etEmail.text.toString().trim()
            val password = binding.etPassword.text.toString().trim()

            if (email.isEmpty() || password.isEmpty()) {
                binding.tvError.text = "Por favor ingresa tu correo y contraseña"
                binding.tvError.visibility = View.VISIBLE
                return@setOnClickListener
            }

            binding.tvError.visibility = View.GONE
            viewModel.signIn(email, password)
        }

        binding.tvCreateAccount.setOnClickListener {
            findNavController().navigate(R.id.action_login_to_register)
        }
    }

    private fun observeState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
            viewModel.uiState.collect { state ->
                when (state) {
                    is UiState.Idle -> Unit
                    is UiState.Loading -> binding.progressBar.visibility = View.VISIBLE
                    is UiState.Success -> {
                        binding.progressBar.visibility = View.GONE
                        val bundle = android.os.Bundle().apply { putString("userId", state.data) }
                        findNavController().navigate(R.id.action_signIn_to_onboarding, bundle)
                    }
                    is UiState.Error -> {
                        binding.progressBar.visibility = View.GONE
                        binding.tvError.text = state.message
                        binding.tvError.visibility = View.VISIBLE
                    }
                }
            }
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}