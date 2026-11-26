package br.com.clinicavet.dto;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
public record UsuarioRequest(
        @NotBlank(message = "Informe o nome.") @Size(max = 120) String nome,
        @NotBlank(message = "Informe o e-mail.") @Email(message = "E-mail invÃ¡lido.") String email,
        @Size(min = 6, max = 60, message = "A senha deve ter entre 6 e 60 caracteres.") String senha,
        @NotBlank(message = "Informe o perfil.") String perfil,
        @Size(max = 255) String fotoUrl,
        Long tutorId,
        Boolean ativo) {}