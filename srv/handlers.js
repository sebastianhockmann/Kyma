import cds from '@sap/cds';
import { getDestination } from '@sap-cloud-sdk/connectivity';
import { executeHttpRequest } from '@sap-cloud-sdk/http-client';

const LOG = cds.log('onprem');

export default cds.service.impl(async function () {
  const { Books } = this.entities;

  // Beispiel: kleiner Default-Hook
  this.after('READ', Books, each => {
    if (each.stock <= 0) each.title += ' (ausverkauft)';
  });

  // Action, die über Destination einen On-Prem-Endpoint aufruft
  this.on('onpremPing', async () => {
    try {
      // Destination-Name in BTP/Subaccount anlegen: "onprem-backend"
      const dest = await getDestination({ destinationName: 'onprem-backend' });
      if (!dest) throw new Error('Destination "onprem-backend" nicht gefunden.');

      const { data, status } = await executeHttpRequest(dest, {
        method: 'GET',
        url: '/health' // muss im Cloud Connector freigegeben sein
      });

      LOG.info('onpremPing OK', { status });
      return `OK (${status}): ${typeof data === 'string' ? data : JSON.stringify(data)}`;
    } catch (e) {
      LOG.warn('onpremPing FAIL', e);
      return `FAIL: ${e.message}`;
    }
  });
});
