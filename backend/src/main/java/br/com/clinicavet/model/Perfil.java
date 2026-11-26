package br.com.clinicavet.model;
import jakarta.persistence.*;
import lombok.*;
@Entity
@Table(name = "perfil")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Perfil {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, unique = true, length = 30)
    private String nome;
    @Column(nullable = false, length = 120)
    private String descricao;
}