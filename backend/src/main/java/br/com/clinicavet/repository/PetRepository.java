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