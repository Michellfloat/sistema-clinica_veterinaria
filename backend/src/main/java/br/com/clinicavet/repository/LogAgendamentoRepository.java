package br.com.clinicavet.repository;
import br.com.clinicavet.model.LogAgendamento;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface LogAgendamentoRepository extends JpaRepository<LogAgendamento, Long> {
    List<LogAgendamento> findTop100ByOrderByDataHoraDesc();
}