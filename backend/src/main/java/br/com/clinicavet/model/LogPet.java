package br.com.clinicavet.model;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity
@Table(name = "log_pet")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LogPet {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "pet_id", nullable = false)
    private Long petId;
    @Column(nullable = false, length = 30)
    private String acao;
    @Column(nullable = false, length = 500)
    private String descricao;
    @Column(name = "usuario_email", nullable = false, length = 120)
    private String usuarioEmail;
    @Column(name = "data_hora", nullable = false)
    private LocalDateTime dataHora;
}