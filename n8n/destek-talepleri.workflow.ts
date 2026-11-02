import { workflow, node, trigger, ifElse, newCredential, expr } from '@n8n/workflow-sdk';

// Hastane Destek Talepleri — n8n workflow (source kept in the repo; the live copy is in n8n).
// Called only by the hospital .NET API (WebAppointment.Api, Support controller), which sends
// the shared X-Destek-Anahtari header. Rows live in the "Talepler" sheet of the
// "Destek Talepleri" spreadsheet.

const sheetDoc = { __rl: true, mode: 'id', value: '1V34JLRR14YK8jtgRP8baORtonQtXQydIbDQORleAjmQ', cachedResultName: 'Destek Talepleri' };
const sheetTab = { __rl: true, mode: 'name', value: 'Talepler' };
const sheetsCred = { googleSheetsOAuth2Api: newCredential('Google Sheets (Google Cloud OAuth)') };
const apiKeyCred = { httpHeaderAuth: newCredential('Destek API Anahtari') };

const columnSchema = [
  { id: 'TalepNo', displayName: 'TalepNo', required: false, defaultMatch: true, display: true, type: 'string', canBeUsedToMatch: true },
  { id: 'OlusturmaTarihi', displayName: 'OlusturmaTarihi', required: false, defaultMatch: false, display: true, type: 'string', canBeUsedToMatch: false },
  { id: 'KullaniciId', displayName: 'KullaniciId', required: false, defaultMatch: false, display: true, type: 'string', canBeUsedToMatch: false },
  { id: 'AdSoyad', displayName: 'AdSoyad', required: false, defaultMatch: false, display: true, type: 'string', canBeUsedToMatch: false },
  { id: 'Iletisim', displayName: 'Iletisim', required: false, defaultMatch: false, display: true, type: 'string', canBeUsedToMatch: false },
  { id: 'Kategori', displayName: 'Kategori', required: false, defaultMatch: false, display: true, type: 'string', canBeUsedToMatch: false },
  { id: 'Oncelik', displayName: 'Oncelik', required: false, defaultMatch: false, display: true, type: 'string', canBeUsedToMatch: false },
  { id: 'Konu', displayName: 'Konu', required: false, defaultMatch: false, display: true, type: 'string', canBeUsedToMatch: false },
  { id: 'Aciklama', displayName: 'Aciklama', required: false, defaultMatch: false, display: true, type: 'string', canBeUsedToMatch: false },
  { id: 'Durum', displayName: 'Durum', required: false, defaultMatch: false, display: true, type: 'string', canBeUsedToMatch: false },
  { id: 'GuncellemeTarihi', displayName: 'GuncellemeTarihi', required: false, defaultMatch: false, display: true, type: 'string', canBeUsedToMatch: false },
  { id: 'YetkiliNotu', displayName: 'YetkiliNotu', required: false, defaultMatch: false, display: true, type: 'string', canBeUsedToMatch: false }
];

// ── 1. Create ─────────────────────────────────────────────
const createHook = trigger({
  type: 'n8n-nodes-base.webhook', version: 2.2,
  config: {
    name: 'POST destek/talep',
    parameters: { httpMethod: 'POST', path: 'destek/talep', authentication: 'headerAuth', responseMode: 'responseNode', options: {} },
    credentials: apiKeyCred
  }
});

const buildTicket = node({
  type: 'n8n-nodes-base.code', version: 2,
  config: {
    name: 'Talep numarasi uret',
    parameters: {
      mode: 'runOnceForAllItems',
      jsCode: 'const b = $input.first().json.body || {};\n'
        + 'const s = (v) => (v === undefined || v === null) ? "" : String(v).trim();\n'
        + 'const required = { adSoyad: "Ad soyad", konu: "Konu", aciklama: "Açıklama" };\n'
        + 'for (const [k, label] of Object.entries(required)) {\n'
        + '  if (!s(b[k])) return [{ json: { ok: false, error: label + " zorunludur." } }];\n'
        + '}\n'
        + 'const tr = new Date(Date.now() + 3 * 3600 * 1000);\n'
        + 'const ymd = tr.toISOString().slice(0, 10).replace(/-/g, "");\n'
        + 'const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";\n'
        + 'let suffix = "";\n'
        + 'for (let i = 0; i < 5; i++) suffix += alphabet[Math.floor(Math.random() * alphabet.length)];\n'
        + 'const stamp = tr.toISOString().slice(0, 16).replace("T", " ");\n'
        + 'return [{ json: { ok: true, row: {\n'
        + '  TalepNo: "DT-" + ymd + "-" + suffix,\n'
        + '  OlusturmaTarihi: stamp,\n'
        + '  KullaniciId: s(b.kullaniciId),\n'
        + '  AdSoyad: s(b.adSoyad).slice(0, 120),\n'
        + '  Iletisim: s(b.iletisim).slice(0, 120),\n'
        + '  Kategori: s(b.kategori) || "Genel",\n'
        + '  Oncelik: s(b.oncelik) || "Normal",\n'
        + '  Konu: s(b.konu).slice(0, 200),\n'
        + '  Aciklama: s(b.aciklama).slice(0, 4000),\n'
        + '  Durum: "Açık",\n'
        + '  GuncellemeTarihi: stamp,\n'
        + '  YetkiliNotu: ""\n'
        + '} } }];'
    }
  }
});

const isValidCreate = ifElse({
  version: 2.2,
  config: {
    name: 'Gecerli mi?',
    parameters: {
      conditions: {
        options: { caseSensitive: true, leftValue: '', typeValidation: 'loose' },
        conditions: [{ leftValue: expr('{{ $json.ok }}'), operator: { type: 'boolean', operation: 'true', singleValue: true } }],
        combinator: 'and'
      }
    }
  }
});

const appendRow = node({
  type: 'n8n-nodes-base.googleSheets', version: 4.7,
  config: {
    name: 'Sheets: talep ekle',
    parameters: {
      resource: 'sheet', operation: 'append', authentication: 'oAuth2',
      documentId: sheetDoc, sheetName: sheetTab,
      columns: {
        mappingMode: 'defineBelow',
        value: {
          TalepNo: expr('{{ $json.row.TalepNo }}'),
          OlusturmaTarihi: expr('{{ $json.row.OlusturmaTarihi }}'),
          KullaniciId: expr('{{ $json.row.KullaniciId }}'),
          AdSoyad: expr('{{ $json.row.AdSoyad }}'),
          Iletisim: expr('{{ $json.row.Iletisim }}'),
          Kategori: expr('{{ $json.row.Kategori }}'),
          Oncelik: expr('{{ $json.row.Oncelik }}'),
          Konu: expr('{{ $json.row.Konu }}'),
          Aciklama: expr('{{ $json.row.Aciklama }}'),
          Durum: expr('{{ $json.row.Durum }}'),
          GuncellemeTarihi: expr('{{ $json.row.GuncellemeTarihi }}'),
          YetkiliNotu: ''
        },
        schema: columnSchema
      },
      options: { cellFormat: 'RAW' }
    },
    credentials: sheetsCred
  }
});

const respondCreated = node({
  type: 'n8n-nodes-base.respondToWebhook', version: 1.5,
  config: {
    name: 'Yanit: olusturuldu',
    parameters: {
      respondWith: 'json',
      responseBody: expr('{{ JSON.stringify($("Talep numarasi uret").first().json.row) }}'),
      options: { responseCode: 201 }
    }
  }
});

const respondInvalid = node({
  type: 'n8n-nodes-base.respondToWebhook', version: 1.5,
  config: {
    name: 'Yanit: gecersiz talep',
    parameters: { respondWith: 'json', responseBody: expr('{{ JSON.stringify({ error: $json.error }) }}'), options: { responseCode: 400 } }
  }
});

// ── 2. Query ──────────────────────────────────────────────
const queryHook = trigger({
  type: 'n8n-nodes-base.webhook', version: 2.2,
  config: {
    name: 'GET destek/sorgula',
    parameters: { httpMethod: 'GET', path: 'destek/sorgula', authentication: 'headerAuth', responseMode: 'responseNode', options: {} },
    credentials: apiKeyCred
  }
});

const findForQuery = node({
  type: 'n8n-nodes-base.googleSheets', version: 4.7,
  config: {
    name: 'Sheets: talebi bul',
    alwaysOutputData: true,
    parameters: {
      resource: 'sheet', operation: 'read', authentication: 'oAuth2',
      documentId: sheetDoc, sheetName: sheetTab,
      filtersUI: { values: [{ lookupColumn: 'TalepNo', lookupValue: expr('{{ ($json.query.talepNo || "").trim().toUpperCase() }}') }] },
      options: { returnFirstMatch: true }
    },
    credentials: sheetsCred
  }
});

const foundForQuery = ifElse({
  version: 2.2,
  config: {
    name: 'Bulundu mu?',
    parameters: {
      conditions: {
        options: { caseSensitive: true, leftValue: '', typeValidation: 'loose' },
        conditions: [{ leftValue: expr('{{ $json.TalepNo }}'), operator: { type: 'string', operation: 'notEmpty', singleValue: true } }],
        combinator: 'and'
      }
    }
  }
});

const respondTicket = node({
  type: 'n8n-nodes-base.respondToWebhook', version: 1.5,
  config: { name: 'Yanit: talep', parameters: { respondWith: 'firstIncomingItem', options: { responseCode: 200 } } }
});

const respondNotFound = node({
  type: 'n8n-nodes-base.respondToWebhook', version: 1.5,
  config: {
    name: 'Yanit: bulunamadi',
    parameters: { respondWith: 'json', responseBody: '{"error":"Talep bulunamadı."}', options: { responseCode: 404 } }
  }
});

// ── 3. Update status ──────────────────────────────────────
const statusHook = trigger({
  type: 'n8n-nodes-base.webhook', version: 2.2,
  config: {
    name: 'POST destek/durum',
    parameters: { httpMethod: 'POST', path: 'destek/durum', authentication: 'headerAuth', responseMode: 'responseNode', options: {} },
    credentials: apiKeyCred
  }
});

const findForUpdate = node({
  type: 'n8n-nodes-base.googleSheets', version: 4.7,
  config: {
    name: 'Sheets: guncellenecek talep',
    alwaysOutputData: true,
    parameters: {
      resource: 'sheet', operation: 'read', authentication: 'oAuth2',
      documentId: sheetDoc, sheetName: sheetTab,
      filtersUI: { values: [{ lookupColumn: 'TalepNo', lookupValue: expr('{{ ($json.body.talepNo || "").trim().toUpperCase() }}') }] },
      options: { returnFirstMatch: true }
    },
    credentials: sheetsCred
  }
});

const foundForUpdate = ifElse({
  version: 2.2,
  config: {
    name: 'Guncellenecek talep var mi?',
    parameters: {
      conditions: {
        options: { caseSensitive: true, leftValue: '', typeValidation: 'loose' },
        conditions: [{ leftValue: expr('{{ $json.TalepNo }}'), operator: { type: 'string', operation: 'notEmpty', singleValue: true } }],
        combinator: 'and'
      }
    }
  }
});

const updateRow = node({
  type: 'n8n-nodes-base.googleSheets', version: 4.7,
  config: {
    name: 'Sheets: durumu guncelle',
    parameters: {
      resource: 'sheet', operation: 'update', authentication: 'oAuth2',
      documentId: sheetDoc, sheetName: sheetTab,
      columns: {
        mappingMode: 'defineBelow',
        matchingColumns: ['TalepNo'],
        value: {
          TalepNo: expr('{{ $json.TalepNo }}'),
          Durum: expr('{{ $("POST destek/durum").first().json.body.durum || $json.Durum }}'),
          YetkiliNotu: expr('{{ $("POST destek/durum").first().json.body.not ?? $json.YetkiliNotu }}'),
          GuncellemeTarihi: expr('{{ $now.setZone("Europe/Istanbul").toFormat("yyyy-MM-dd HH:mm") }}')
        },
        schema: columnSchema
      },
      options: { cellFormat: 'RAW' }
    },
    credentials: sheetsCred
  }
});

const respondUpdated = node({
  type: 'n8n-nodes-base.respondToWebhook', version: 1.5,
  config: {
    name: 'Yanit: guncellendi',
    parameters: {
      respondWith: 'json',
      // The update node only returns the changed columns; answer with the whole row.
      responseBody: expr('{{ JSON.stringify(Object.assign({}, $("Sheets: guncellenecek talep").first().json, $json)) }}'),
      options: { responseCode: 200 }
    }
  }
});

const respondUpdateNotFound = node({
  type: 'n8n-nodes-base.respondToWebhook', version: 1.5,
  config: {
    name: 'Yanit: guncellenecek talep yok',
    parameters: { respondWith: 'json', responseBody: '{"error":"Talep bulunamadı."}', options: { responseCode: 404 } }
  }
});

// ── 4. List (admin panels) ────────────────────────────────
const listHook = trigger({
  type: 'n8n-nodes-base.webhook', version: 2.2,
  config: {
    name: 'GET destek/liste',
    parameters: { httpMethod: 'GET', path: 'destek/liste', authentication: 'headerAuth', responseMode: 'responseNode', options: {} },
    credentials: apiKeyCred
  }
});

const readAll = node({
  type: 'n8n-nodes-base.googleSheets', version: 4.7,
  config: {
    name: 'Sheets: tum talepler',
    alwaysOutputData: true,
    parameters: { resource: 'sheet', operation: 'read', authentication: 'oAuth2', documentId: sheetDoc, sheetName: sheetTab, options: {} },
    credentials: sheetsCred
  }
});

const respondList = node({
  type: 'n8n-nodes-base.respondToWebhook', version: 1.5,
  config: { name: 'Yanit: liste', parameters: { respondWith: 'allIncomingItems', options: { responseCode: 200 } } }
});

export default workflow('hastane-destek-talepleri', 'Hastane Destek Talepleri')
  .add(listHook).to(readAll).to(respondList)
  .add(createHook).to(buildTicket).to(isValidCreate
    .onTrue(appendRow.to(respondCreated))
    .onFalse(respondInvalid))
  .add(queryHook).to(findForQuery).to(foundForQuery
    .onTrue(respondTicket)
    .onFalse(respondNotFound))
  .add(statusHook).to(findForUpdate).to(foundForUpdate
    .onTrue(updateRow.to(respondUpdated))
    .onFalse(respondUpdateNotFound))
  .group('Talep olustur', [buildTicket, isValidCreate, appendRow, respondCreated, respondInvalid], {
    description: 'Talebi dogrular, DT-YYYYAAGG-XXXXX numarasini uretir, Sheets e ekler'
  })
  .group('Talep sorgula', [findForQuery, foundForQuery, respondTicket, respondNotFound], {
    description: 'Talep numarasiyla Sheets ten kaydi bulur, yoksa 404'
  })
  .group('Durum guncelle', [findForUpdate, foundForUpdate, updateRow, respondUpdated, respondUpdateNotFound], {
    description: 'Talebin durumunu ve yetkili notunu gunceller'
  })
  .group('Talep listesi', [readAll, respondList], {
    description: 'Yonetici paneli icin tum talepleri dondurur'
  });
