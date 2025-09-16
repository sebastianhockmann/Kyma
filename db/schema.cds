using { cuid } from '@sap/cds/common';
namespace my;

entity Books : cuid {
  title  : String(111);
  stock  : Integer;
  price  : Decimal(9,2);
}
