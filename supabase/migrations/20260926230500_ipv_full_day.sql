-- Un IPV por día calendario. El turno es el día completo.

alter table public.ipv_documents drop constraint if exists ipv_documents_unique_shift;

alter table public.ipv_documents
  add constraint ipv_documents_unique_day unique (work_date);

alter table public.ipv_documents
  alter column shift set default 'manana';
