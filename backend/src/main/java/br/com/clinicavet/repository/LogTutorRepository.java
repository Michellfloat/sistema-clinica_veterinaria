package br.com.clinicavet.repository;
import br.com.clinicavet.model.LogTutor;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface LogTutorRepository extends JpaRepository<LogTutor, Long> {
    List<LogTutor> findTop100ByOrderByDataHoraDesc();
}