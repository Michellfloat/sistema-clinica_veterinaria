package br.com.clinicavet.model;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
@Entity
@Table(name = "usuario")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Usuario implements UserDetails {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(nullable = false, length = 120)
    private String nome;
    @Column(nullable = false, unique = true, length = 120)
    private String email;
    @Column(nullable = false, length = 100)
    private String senha;
    @Column(name = "foto_url", length = 255)
    private String fotoUrl;
    @Column(nullable = false)
    @Builder.Default
    private Boolean ativo = true;
    @ManyToOne(fetch = FetchType.EAGER, optional = false)
    @JoinColumn(name = "perfil_id", nullable = false)
    private Perfil perfil;
    /** VÃ­nculo opcional (perfis TUTOR e PET enxergam apenas dados deste tutor). */
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "tutor_id")
    private Tutor tutor;
    @Column(name = "criado_em", nullable = false, updatable = false)
    private LocalDateTime criadoEm;
    @PrePersist
    void aoCriar() { criadoEm = LocalDateTime.now(); }
    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + perfil.getNome()));
    }
    @Override public String getPassword() { return senha; }
    @Override public String getUsername() { return email; }
    @Override public boolean isEnabled() { return Boolean.TRUE.equals(ativo); }
}