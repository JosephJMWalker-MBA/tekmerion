import '../../record/domain/evidence_envelope.dart';
import 'agreement.dart';
import 'agreement_version.dart';

abstract class AgreementRepository {
  Future<void> importAgreementTransaction({
    required EvidenceEnvelope evidence,
    required Agreement agreement,
    required AgreementVersion version,
  });

  Future<List<Agreement>> getAllAgreements();
  Future<List<AgreementVersion>> getVersionsForAgreement(String agreementId);
  Future<EvidenceEnvelope?> getEvidenceAssetById(String evidenceId);
}
