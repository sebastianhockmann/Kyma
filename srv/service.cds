using my from '../db/schema';

service CatalogService {
  entity Books as projection on my.Books;

  @readonly
  action onpremPing() returns String;
}
