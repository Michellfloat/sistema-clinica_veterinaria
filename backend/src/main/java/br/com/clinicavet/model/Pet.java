package br.com.clinicavet.model;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDate;
import java.time.LocalDateTime;
@Entity
@Table(name = "pet")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Pet {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, length = 80)
    private String nome;
    @Column(nullable = false, length = 40)
    private String especie;
    @Column(length = 60)
    private String raca;
    @Column(name = "data_nascimento")
    private LocalDate dataNascimento;
    @Column(nullable = false)
    @Builder.Default
    private Boolean ativo = true;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "tutor_id", nullable = false)
    private Tutor tutor;
    @Column(name = "criado_em", nullable = false, updatable = false)
    private LocalDateTime criadoEm;
    @PrePersist
    void aoCriar() { criadoEm = LocalDateTime.now(); }
}