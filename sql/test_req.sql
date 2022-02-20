-- sqlplus '/ as sysdba' @/tmp/titi &
spool reqtest_dwh_as15.lst
ALTER SESSION SET EVENTS '10046 trace name context forever, level 8';
set time on
set timin on
set termout off
set arraysize 15
with presta_cumul as (
select distinct
nvl(s.id_i_sejour, -2) as id_i_sejour,
coalesce(tarif.id_i_presta_tarif,p.id_i_presta_tarif,-2) as id_i_presta_tarif,
coalesce(psta.id_i_presta, p.id_i_presta,-2) as id_i_presta,
greatest(coalesce(trunc(m.dt_d_debut), trunc(p.dt_d_debut), to_date('01012000','ddmmyyyy')), nvl(trunc(sej.dt_d_sejour_dat_deb), to_date('01012000','ddmmyyyy'))) as dt_d_scd_debut,
least(coalesce(trunc(m.dt_d_fin), trunc(p.dt_d_fin), to_date('31122999','ddmmyyyy')),  nvl(trunc(sej.dt_d_sejour_dat_fin), to_date('31122999','ddmmyyyy'))) as dt_d_scd_fin,
nvl(m.mt_n_tarif ,p.mt_n_tarif_presta) as mt_n_tarif,
nvl(m.mt_n_prix_saisi,
case when p.mt_n_prix_saisi is not null then p.mt_n_prix_saisi
     when p.mt_n_rabais is not null then p.mt_n_tarif_presta - p.mt_n_rabais
     when p.mt_n_rabais_prct is not null then p.mt_n_tarif_presta - p.mt_n_rabais_prct
end) as mt_n_prix_saisi,
p.dt_d_ins,
p.dt_d_upd,
p.lb_v_ins_user,
p.lb_v_upd_user
from kor_ods.sante_hm_presta_sejour p
left join kor_ods.sante_sejour_id s
    on id_v_sejour_source = p.id_i_sejour_hm
    and lb_v_source = 'HM'
left join kor_ods.sante_hm_sejour sej
    on sej.id_i_sejour_hm = p.id_i_sejour_hm
left join kor_ods.sante_hm_multi_presta_sejour m
    on m.id_i_sejour_hm = p.id_i_sejour_hm
    and nvl(m.dt_d_debut, to_date('01012000','ddmmyyyy')) = greatest(nvl(trunc(p.dt_d_debut), to_date('01012000','ddmmyyyy')), trunc(sej.dt_d_sejour_dat_deb))
    and nvl(m.dt_d_fin, to_date('31122999','ddmmyyyy')) = least(nvl(trunc(p.dt_d_fin), to_date('31122999','ddmmyyyy')),  nvl(trunc(sej.dt_d_sejour_dat_fin), to_date('31122999','ddmmyyyy')))
left join kor_ods.sante_hm_presta psta
    on psta.cd_v_presta = m.cd_v_multi_presta
    and psta.id_i_etablissement_hm = m.id_i_etablissement_hm
left join kor_ods.sante_hm_presta_tarif tarif
    on tarif.id_i_etablissement_hm = m.id_i_etablissement_hm
    and tarif.cd_v_presta = m.cd_v_presta_ref
    and trunc(m.dt_d_debut) >= trunc(tarif.DT_D_DEBUT_TARIF)
    and trunc(m.dt_d_debut) < trunc(nvl(tarif.DT_D_FIN_TARIF,to_date('31122999','ddmmyyyy')))
where
p.cd_v_type_presta = 'HOTE'
and nvl(sej.id_c_typ_pmsi,-2) != 0
), def_date as (
select
id_i_sejour,
dt_d_scd_debut as date_key
from presta_cumul
where
dt_d_scd_debut  != dt_d_scd_fin
and id_i_presta != -2
and id_i_presta_tarif != -2
union
select
id_i_sejour,
dt_d_scd_fin as date_key
from presta_cumul
where
dt_d_scd_debut  != dt_d_scd_fin
and id_i_presta != -2
and id_i_presta_tarif != -2
), dim_date as (
select
id_i_sejour,
date_key as dt_d_scd_debut,
lead(date_key) over (partition by id_i_sejour order by date_key asc) as dt_d_scd_fin
from def_date
), scd_tmp as (
select
dim_date.id_i_sejour,
presta_cumul.ID_I_PRESTA_TARIF,
presta_cumul.ID_I_PRESTA,
dim_date.dt_d_scd_debut,
dim_date.dt_d_scd_fin,
presta_cumul.MT_N_TARIF,
presta_cumul.MT_N_PRIX_SAISI,
presta_cumul.DT_D_INS,
presta_cumul.DT_D_UPD,
presta_cumul.LB_V_INS_USER,
presta_cumul.LB_V_UPD_USER
from dim_date
left join presta_cumul
    on presta_cumul.id_i_sejour = dim_date.id_i_sejour
    and presta_cumul.dt_d_scd_debut = dim_date.dt_d_scd_debut
    and presta_cumul.dt_d_scd_fin = dim_date.dt_d_scd_fin
    and presta_cumul.dt_d_scd_debut  != presta_cumul.dt_d_scd_fin
    and presta_cumul.id_i_presta != -2
    and presta_cumul.id_i_presta_tarif != -2
where dim_date.dt_d_scd_fin is not null
), scd as (
select
*
from scd_tmp
where
id_i_presta is not null
union all
select
scd_tmp.id_i_sejour,
max(presta_cumul.ID_I_PRESTA_TARIF),
max(presta_cumul.ID_I_PRESTA),
scd_tmp.dt_d_scd_debut,
scd_tmp.dt_d_scd_fin,
max(presta_cumul.MT_N_TARIF),
max(presta_cumul.MT_N_PRIX_SAISI),
max(presta_cumul.DT_D_INS),
max(presta_cumul.DT_D_UPD),
max(presta_cumul.LB_V_INS_USER),
max(presta_cumul.LB_V_UPD_USER)
from scd_tmp
left join presta_cumul
    on presta_cumul.id_i_sejour = scd_tmp.id_i_sejour
    and presta_cumul.dt_d_scd_debut <= scd_tmp.dt_d_scd_debut
    and presta_cumul.dt_d_scd_fin >= scd_tmp.dt_d_scd_fin
    and presta_cumul.dt_d_scd_debut  != presta_cumul.dt_d_scd_fin
    and presta_cumul.id_i_presta != -2
    and presta_cumul.id_i_presta_tarif != -2
    and (presta_cumul.id_i_sejour, presta_cumul.id_i_presta, presta_cumul.id_i_presta_tarif) not in (select distinct id_i_sejour, id_i_presta, id_i_presta_tarif from scd_tmp where id_i_presta is not null)
where
scd_tmp.id_i_presta is null
group by
scd_tmp.id_i_sejour,
scd_tmp.dt_d_scd_debut,
scd_tmp.dt_d_scd_fin
)
--partie bloquante
--/*
select distinct
id_i_sejour,
id_i_presta_tarif,
id_i_presta,
dt_d_scd_debut,
dt_d_scd_fin,
mt_n_tarif,
nullif(mt_n_prix_saisi,0) as mt_n_prix_saisi,
case when max(dt_d_scd_debut) over (partition by id_i_sejour order by dt_d_scd_debut) = dt_d_scd_debut then 1 else 0 end as is_i_scd_actif,
sysdate as dt_d_ins,
sysdate as dt_d_upd,
lb_v_ins_user,
lb_v_upd_user
from scd;
exit;
