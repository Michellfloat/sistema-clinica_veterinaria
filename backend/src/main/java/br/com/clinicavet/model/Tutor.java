package br.com.clinicavet.model;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity
@Table(name = "tutor")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Tutor {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, length = 120)
    private String nome;
    /** CPF cifrado com AES-256-GCM (LGPD). Nunca Ã© exposto em texto puro. */
    @Column(name = "cpf_criptografado", nullable = false)
    private String cpfCriptografado;
    /** HMAC-SHA256 do CPF: permite unicidade e busca exata sem decifrar. */
    @Column(name = "cpf_hash", nullable = false, unique = true, length = 64)
    private String cpfHash;
    @Column(nullable = false, length = 20)
    private String telefone;
    @Column(nullable = false, length = 120)
    private String email;
    @Column(length = 255)
    private String endereco;
    @Column(nullable = false)
    @Builder.Default
    private Boolean ativo = true;
    @Column(name = "criado_em", nullable = false, updatable = false)
    private LocalDateTime criadoEm;
    @Column(name = "atualizado_em", nullable = false)
    private LocalDateTime atualizadoEm;
    @PrePersist
    void aoCriar() {
        criadoEm = LocalDateTime.now();
        atualizadoEm = criadoEm;
    }
    @PreUpdate
    void aoAtualizar() {
        atualizadoEm = LocalDateTime.now();
    }
}