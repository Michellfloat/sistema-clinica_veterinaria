package br.com.clinicavet.repository;
import br.com.clinicavet.model.LogPet;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface LogPetRepository extends JpaRepository<LogPet, Long> {
    List<LogPet> findTop100ByOrderByDataHoraDesc();
}