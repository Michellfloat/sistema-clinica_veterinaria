package br.com.clinicavet.dto;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
/** O CPF Ã© obrigatÃ³rio na criaÃ§Ã£o e opcional na ediÃ§Ã£o (sÃ³ Ã© regravado se enviado). */
public record TutorRequest(
        @NotBlank(message = "Informe o nome do tutor.") @Size(max = 120) String nome,
        String cpf,
        @NotBlank(message = "Informe o telefone.") @Size(max = 20) String telefone,
        @NotBlank(message = "Informe o e-mail.") @Email(message = "E-mail invÃ¡lido.") @Size(max = 120) String email,
        @Size(max = 255) String endereco) {}