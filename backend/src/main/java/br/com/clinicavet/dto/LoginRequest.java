package br.com.clinicavet.dto;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
public record LoginRequest(
        @NotBlank(message = "Informe o e-mail.") @Email(message = "E-mail invÃ¡lido.") String email,
        @NotBlank(message = "Informe a senha.") String senha) {}