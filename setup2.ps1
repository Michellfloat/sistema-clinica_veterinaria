$base = if (Test-Path "clinica-veterinaria/backend/src/main/java/br/com/clinicavet") { "clinica-veterinaria/backend/src/main/java/br/com/clinicavet" } else { "backend/src/main/java/br/com/clinicavet" }
Set-Location $base
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
function Write-File($path, $content) { [System.IO.File]::WriteAllText((Join-Path (Get-Location).ProviderPath $path), $content, $utf8NoBom) }
Write-File "ClinicaVeterinariaApplication.java" @'
package br.com.clinicavet;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
@SpringBootApplication
public class ClinicaVeterinariaApplication {
    public static void main(String[] args) {
        SpringApplication.run(ClinicaVeterinariaApplication.class, args);
    }
}
'@
Write-File "model/Perfil.java" @'
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
'@
Write-File "model/Tutor.java" @'
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
    /** CPF cifrado com AES-256-GCM (LGPD). Nunca é exposto em texto puro. */
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
'@
Write-File "model/Usuario.java" @'
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
    /** Vínculo opcional (perfis TUTOR e PET enxergam apenas dados deste tutor). */
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
'@
Write-File "model/Pet.java" @'
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
'@
Write-File "model/StatusAgendamento.java" @'
package br.com.clinicavet.model;
public enum StatusAgendamento { AGENDADO, CONFIRMADO, CONCLUIDO, CANCELADO }
'@
Write-File "model/Agendamento.java" @'
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
'@
Write-File "model/LogTutor.java" @'
package br.com.clinicavet.model;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity
@Table(name = "log_tutor")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LogTutor {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "tutor_id", nullable = false)
    private Long tutorId;
    @Column(nullable = false, length = 30)
    private String acao;
    @Column(nullable = false, length = 500)
    private String descricao;
    @Column(name = "usuario_email", nullable = false, length = 120)
    private String usuarioEmail;
    @Column(name = "data_hora", nullable = false)
    private LocalDateTime dataHora;
}
'@
Write-File "model/LogPet.java" @'
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
'@
Write-File "model/LogAgendamento.java" @'
package br.com.clinicavet.model;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity
@Table(name = "log_agendamento")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LogAgendamento {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "agendamento_id", nullable = false)
    private Long agendamentoId;
    @Column(nullable = false, length = 30)
    private String acao;
    @Column(nullable = false, length = 500)
    private String descricao;
    @Column(name = "data_anterior")
    private LocalDateTime dataAnterior;
    @Column(name = "data_nova")
    private LocalDateTime dataNova;
    @Column(name = "usuario_email", nullable = false, length = 120)
    private String usuarioEmail;
    @Column(name = "data_hora", nullable = false)
    private LocalDateTime dataHora;
}
'@
Write-File "model/LogUsuario.java" @'
package br.com.clinicavet.model;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity
@Table(name = "log_usuario")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LogUsuario {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "usuario_id", nullable = false)
    private Long usuarioId;
    @Column(nullable = false, length = 30)
    private String acao;
    @Column(nullable = false, length = 500)
    private String descricao;
    @Column(name = "usuario_email", nullable = false, length = 120)
    private String usuarioEmail;
    @Column(name = "data_hora", nullable = false)
    private LocalDateTime dataHora;
}
'@
Write-File "repository/PerfilRepository.java" @'
package br.com.clinicavet.repository;
import br.com.clinicavet.model.Perfil;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface PerfilRepository extends JpaRepository<Perfil, Long> {
    Optional<Perfil> findByNome(String nome);
}
'@
Write-File "repository/UsuarioRepository.java" @'
package br.com.clinicavet.repository;
import br.com.clinicavet.model.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface UsuarioRepository extends JpaRepository<Usuario, Long> {
    Optional<Usuario> findByEmail(String email);
    boolean existsByEmail(String email);
}
'@
Write-File "repository/TutorRepository.java" @'
package br.com.clinicavet.repository;
import br.com.clinicavet.model.Tutor;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;
public interface TutorRepository extends JpaRepository<Tutor, Long> {
    List<Tutor> findByAtivoTrueOrderByNomeAsc();
    Optional<Tutor> findByIdAndAtivoTrue(Long id);
    boolean existsByCpfHash(String cpfHash);
    boolean existsByCpfHashAndIdNot(String cpfHash, Long id);
    long countByAtivoTrue();
    @Query("""
           SELECT t FROM Tutor t
           WHERE t.ativo = true AND (
                 LOWER(t.nome)  LIKE LOWER(CONCAT('%', :termo, '%'))
              OR LOWER(t.email) LIKE LOWER(CONCAT('%', :termo, '%'))
              OR t.telefone     LIKE CONCAT('%', :termo, '%')
              OR t.cpfHash = :cpfHash)
           ORDER BY t.nome ASC
           """)
    List<Tutor> buscar(@Param("termo") String termo, @Param("cpfHash") String cpfHash);
}
'@
Write-File "repository/PetRepository.java" @'
package br.com.clinicavet.repository;
import br.com.clinicavet.model.Pet;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;
public interface PetRepository extends JpaRepository<Pet, Long> {
    @Query("SELECT p FROM Pet p JOIN FETCH p.tutor WHERE p.ativo = true ORDER BY p.nome")
    List<Pet> listarAtivos();
    @Query("SELECT p FROM Pet p JOIN FETCH p.tutor t WHERE p.ativo = true AND t.id = :tutorId ORDER BY p.nome")
    List<Pet> listarPorTutor(@Param("tutorId") Long tutorId);
    @Query("""
           SELECT p FROM Pet p JOIN FETCH p.tutor t
           WHERE p.ativo = true AND (LOWER(p.nome) LIKE LOWER(CONCAT('%', :termo, '%'))
              OR LOWER(p.especie) LIKE LOWER(CONCAT('%', :termo, '%'))
              OR LOWER(t.nome) LIKE LOWER(CONCAT('%', :termo, '%')))
           ORDER BY p.nome
           """)
    List<Pet> buscar(@Param("termo") String termo);
    @Query("SELECT p FROM Pet p JOIN FETCH p.tutor WHERE p.id = :id AND p.ativo = true")
    Optional<Pet> buscarAtivoPorId(@Param("id") Long id);
    long countByAtivoTrue();
    long countByTutorIdAndAtivoTrue(Long tutorId);
}
'@
Write-File "repository/AgendamentoRepository.java" @'
package br.com.clinicavet.repository;
import br.com.clinicavet.model.Agendamento;
import br.com.clinicavet.model.StatusAgendamento;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
public interface AgendamentoRepository extends JpaRepository<Agendamento, Long> {
    @Query("""
           SELECT a FROM Agendamento a JOIN FETCH a.pet p JOIN FETCH p.tutor
           ORDER BY a.dataHora ASC
           """)
    List<Agendamento> listarOrdenados();
    @Query("""
           SELECT a FROM Agendamento a JOIN FETCH a.pet p JOIN FETCH p.tutor t
           WHERE t.id = :tutorId ORDER BY a.dataHora ASC
           """)
    List<Agendamento> listarPorTutor(@Param("tutorId") Long tutorId);
    @Query("SELECT a FROM Agendamento a JOIN FETCH a.pet p JOIN FETCH p.tutor WHERE a.id = :id")
    Optional<Agendamento> buscarPorId(@Param("id") Long id);
    boolean existsByPetIdAndDataHoraAndStatusNot(Long petId, LocalDateTime dataHora, StatusAgendamento status);
    long countByDataHoraBetweenAndStatusNot(LocalDateTime ini, LocalDateTime fim, StatusAgendamento status);
    long countByPetId(Long petId);
}
'@
foreach ($N in @("Tutor","Pet","Agendamento","Usuario")) {
    Write-File "repository/Log${N}Repository.java" @"
package br.com.clinicavet.repository;
import br.com.clinicavet.model.Log${N};
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface Log${N}Repository extends JpaRepository<Log${N}, Long> {
    List<Log${N}> findTop100ByOrderByDataHoraDesc();
}
"@
}
Get-ChildItem repository, model | Select-Object DirectoryName, Name