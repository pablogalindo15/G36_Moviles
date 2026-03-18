package com.smartfinance.feature.signin

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import com.smartfinance.core.model.UiState
import com.smartfinance.databinding.FragmentSigninBinding
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.flow.collectLatest
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
            val email = binding.etEmail.text.toString()
            val password = binding.etPassword.text.toString()
            viewModel.signIn(email, password)
        }

        binding.tvCreateAccount.setOnClickListener {
            findNavController().navigate(R.id.action_login_to_register)
        }
    }

    private fun observeState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewModel.uiState.collectLatest { state ->
                when (state) {
                    is UiState.Idle -> Unit
                    is UiState.Loading -> binding.progressBar.visibility = View.VISIBLE
                    is UiState.Success -> {
                        binding.progressBar.visibility = View.GONE
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

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}