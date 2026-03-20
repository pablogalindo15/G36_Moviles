package com.smartfinance.feature.register

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.core.os.bundleOf
import androidx.core.widget.doAfterTextChanged
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.navigation.fragment.findNavController
import com.google.android.material.snackbar.Snackbar
import com.smartfinance.R
import com.smartfinance.core.model.UiState
import com.smartfinance.databinding.FragmentRegisterBinding
import com.smartfinance.domain.register.RegisterRequestDTO
import com.smartfinance.domain.register.RegisterValidationResult
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import android.net.Uri
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import java.io.File

@AndroidEntryPoint
class RegisterFragment : Fragment() {

    private var selectedImageUri: Uri? = null
    private var cameraImageUri: Uri? = null
    private var _binding: FragmentRegisterBinding? = null
    private val binding get() = _binding!!

    private val viewModel: RegisterViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentRegisterBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupActions()
        setupInlineErrorReset()
        observeValidationState()
        observeUiState()
        setupLoginCtaStyle()
    }

    private val pickImageLauncher = registerForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            selectedImageUri = uri
            binding.profileImageView.setImageURI(uri)
        }
    }

    private val takePictureLauncher = registerForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success && cameraImageUri != null) {
            selectedImageUri = cameraImageUri
            binding.profileImageView.setImageURI(cameraImageUri)
        }
    }

    private fun createImageUri(): Uri {
        val imageFile = File.createTempFile(
            "profile_${System.currentTimeMillis()}",
            ".jpg",
            requireContext().cacheDir
        )

        return FileProvider.getUriForFile(
            requireContext(),
            "${requireContext().packageName}.provider",
            imageFile
        )
    }

    private fun uriToByteArray(uri: Uri): ByteArray? {
        return try {
            requireContext().contentResolver.openInputStream(uri)?.use { 
                it.readBytes()
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun setupActions() {
        binding.buttonBack.setOnClickListener {
            findNavController().navigateUp()
        }

        binding.profilePhotoCard.setOnClickListener {
            MaterialAlertDialogBuilder(requireContext())
                .setTitle("Profile photo")
                .setItems(arrayOf("Take photo", "Choose from gallery")) { _, which ->
                    when (which) {
                        0 -> {
                            cameraImageUri = createImageUri()
                            takePictureLauncher.launch(cameraImageUri)
                        }
                        1 -> {
                            pickImageLauncher.launch(
                                PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                            )
                        }
                    }
                }
                .show()
        }

        binding.buttonCreateAccount.setOnClickListener {
            val dto = RegisterRequestDTO(
                fullName = binding.fullNameInput.text?.toString().orEmpty(),
                email = binding.emailInput.text?.toString().orEmpty(),
                password = binding.passwordInput.text?.toString().orEmpty(),
                confirmPassword = binding.confirmPasswordInput.text?.toString().orEmpty(),
                acceptedTerms = binding.termsCheckbox.isChecked,
                profileImage = selectedImageUri?.let { uriToByteArray(it) }
            )
            viewModel.submitRegister(dto)
        }

        binding.loginCta.setOnClickListener {
            findNavController().navigate(R.id.signInFragment)
        }

    }

    private fun setupLoginCtaStyle() {
        val text = "Already have an account? Log in"
        val spannable = android.text.SpannableString(text)

        val start = text.indexOf("Log in")
        val end = start + "Log in".length

        spannable.setSpan(
            android.text.style.UnderlineSpan(),
            start,
            end,
            android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
        )

        binding.loginCta.text = spannable
    }

    private fun setupInlineErrorReset() {
        binding.fullNameInput.doAfterTextChanged {
            binding.fullNameLayout.error = null
        }
        binding.emailInput.doAfterTextChanged {
            binding.emailLayout.error = null
        }
        binding.passwordInput.doAfterTextChanged {
            binding.passwordLayout.error = null
        }
        binding.confirmPasswordInput.doAfterTextChanged {
            binding.confirmPasswordLayout.error = null
        }
        binding.termsCheckbox.setOnCheckedChangeListener { _, _ ->
            binding.termsErrorText.visibility = View.GONE
        }
    }

    private fun observeValidationState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.validationState.collect { validation ->
                    renderValidation(validation)
                }
            }
        }
    }

    private fun observeUiState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    when (state) {
                        is UiState.Idle -> {
                            binding.progressIndicator.visibility = View.GONE
                            binding.buttonCreateAccount.isEnabled = true
                        }
                        is UiState.Loading -> {
                            binding.progressIndicator.visibility = View.VISIBLE
                            binding.buttonCreateAccount.isEnabled = false
                        }
                        is UiState.Success -> {
                            binding.progressIndicator.visibility = View.GONE
                            binding.buttonCreateAccount.isEnabled = true
                            findNavController().navigate(
                                R.id.action_registerFragment_to_onboardingFragment,
                                bundleOf("userId" to state.data.userId)
                            )
                            viewModel.resetUiState()
                        }
                        is UiState.Error -> {
                            binding.progressIndicator.visibility = View.GONE
                            binding.buttonCreateAccount.isEnabled = true
                            Snackbar.make(binding.root, state.message, Snackbar.LENGTH_LONG).show()
                        }
                    }
                }
            }
        }
    }

    private fun renderValidation(validation: RegisterValidationResult) {
        binding.fullNameLayout.error = validation.fullNameError
        binding.emailLayout.error = validation.emailError
        binding.passwordLayout.error = validation.passwordError
        binding.confirmPasswordLayout.error = validation.confirmPasswordError

        if (validation.termsError == null) {
            binding.termsErrorText.visibility = View.GONE
            binding.termsErrorText.text = null
        } else {
            binding.termsErrorText.visibility = View.VISIBLE
            binding.termsErrorText.text = validation.termsError
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
