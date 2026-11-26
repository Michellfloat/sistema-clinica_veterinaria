package br.com.clinicavet.repository;
import br.com.clinicavet.model.LogUsuario;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface LogUsuarioRepository extends JpaRepository<LogUsuario, Long> {
    List<LogUsuario> findTop100ByOrderByDataHoraDesc();
}