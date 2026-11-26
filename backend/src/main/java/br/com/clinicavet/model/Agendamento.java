package br.com.clinicavet.model;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity
@Table(name = "agendamento")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Agendamento {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "data_hora", nullable = false)
    private LocalDateTime dataHora;
    @Column(nullable = false, length = 160)
    private String motivo;
    @Column(length = 255)
    private String observacoes;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private StatusAgendamento status = StatusAgendamento.AGENDADO;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pet_id", nullable = false)
    private Pet pet;
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "usuario_id")
    private Usuario usuario;
    @Column(name = "criado_em", nullable = false, updatable = false)
    private LocalDateTime criadoEm;
    @PrePersist
    void aoCriar() { criadoEm = LocalDateTime.now(); }
}