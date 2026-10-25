<?php
// ruleid: php-sql-by-id-without-tenant-predicate
$db->query("SELECT * FROM invoices WHERE id = " . $_GET['id']);

// ruleid: php-sql-by-id-without-tenant-predicate
$stmt = $pdo->prepare('UPDATE invoices SET paid = 1 WHERE invoice_id = ?');

// ruleid: php-sql-by-id-without-tenant-predicate
mysqli_query($conn, "DELETE FROM docs WHERE doc_id = " . intval($_POST['id']));

// ruleid: php-sql-by-id-without-tenant-predicate
$invoice = $invoiceRepo->find($_GET['id']);

// ruleid: php-sql-by-id-without-tenant-predicate
$item = $repo->findOneBy(['id' => $id]);

// ok: php-sql-by-id-without-tenant-predicate
$db->query("SELECT * FROM invoices WHERE id = " . (int)$_GET['id'] . " AND tenant_id = " . $tid);

// ok: php-sql-by-id-without-tenant-predicate
$stmt = $pdo->prepare('SELECT * FROM invoices WHERE org_id = ? AND id = ?');

// ok: php-sql-by-id-without-tenant-predicate
$db->query("SELECT name FROM countries");
