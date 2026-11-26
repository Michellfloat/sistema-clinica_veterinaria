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