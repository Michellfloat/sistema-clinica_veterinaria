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