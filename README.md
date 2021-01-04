# redmine-rdbms-migration

Redmine の RDBMS を MySQL から PostgreSQL に変更する

## 前提条件

- 対象環境の Redmine は 3.4.x
- 移行元は MySQL 5.7
- 移行先は PostgreSQL 11
- 現行データは1日1回 mysqldump にてダンプファイルを作成
- Redmine 自体は10年近く使用しているため、プラグインのテーブルが残った状態になってる（Redmineのプラグインからは既に削除されている）。
  
## 実施環境セットアップ

### Redmine データベースの作成

```bash
mysql -h 127.0.0.1  -u root -p < mysqldump_20200XXXXXXXXX
```

### Rails セットアップ

```bash
wget https://www.redmine.org/releases/redmine-3.4.5.tar.gz
tar zxvf redmine-3.4.5.tar.gz
cd redmine-3.4.5
cp config/database.yml.example configdatabase.yml
vi config
bundle install
```

### 移行データ作成

1. MySQLからデータ出力
2. スキーマ定義を MySQL から PostgreSQL へ移行
   - `rak db:schem:dump` で MySQL の定義を出力
   - `rak db:schem:load` で PostgreSQL に定義を生成

### 不要テーブルの掃除

※ Redmine の プラグインの出し入れで残ってる不要なテーブルおよびデータ削除

```sql
DROP TABLE chart_done_ratios_20121107;
DROP TABLE chart_issue_statuses_20121107;
DROP TABLE chart_saved_conditions_20121107;
DROP TABLE chart_time_entries_20121107;
DROP TABLE work_kb_articles;
DROP TABLE work_kb_categories;
DROP TABLE work_ratings;
DROP TABLE work_viewings;
```

## マイグレーション

### yaml_db

#### セットアップ

GitHubからダウンロードしてきてRedmineのpluginに追加するだけ。
実施時のバージョンは`0.7.0`

#### 実施と結果

```console
RAILS_ENV=production rake db:migrate
RAILS_ENV=production rake db:data:dump
vi config/database.yml
RAILS_ENV=production rake db:data:load
```

- yaml_db は移行元と移行先が同じスキーマ定義でないとだめ
- Rails を長期間つかっていると、プライグインの追加・削除等あるため、使用していないテーブルが残った状態になっている→つまり使えない
- [PostgreSQL 10 : Each sequence does not have `increment_by` column, need to use `pg_sequences`](https://github.com/rails/rails/issues/28780)が発生するので、PostgreSQLを9.6以下にしないとこのバージョンでは上手く動かない

### pg_loader

Redmine のプラグインでは上手く移行できないため、Redmine に依存せず単なる MySQL から PostgreSQL へのマイグレーションとして行う。

#### セットアップ

[pg_loader](https://pgloader.io/) を [brew](https://formulae.brew.sh/formula/pgloader) でセットアップ

```console
$ brew reinstall pgloader
$ pgloader -V
pgloader version "3.6.2"
compiled with SBCL 2.0.2
```

移行元と移行先の設定を行う

```bash
$ cat config/commands.load
load database
    from mysql://root:redmine@127.0.0.1/redmine
    into pgsql://redmine:redmine@localhost/redmine
    alter schema 'redmine' rename to 'public';
```

#### 実施と結果

```console
$ pgloader ./config/commands.load
2020-09-26T00:06:00.009000+01:00 LOG pgloader version "3.6.2"
2020-09-26T00:06:00.153000+01:00 LOG Migrating from #<MYSQL-CONNECTION mysql://root@127.0.0.1:3306/redmine {1005C2F7F3}>
2020-09-26T00:06:00.153000+01:00 LOG Migrating into #<PGSQL-CONNECTION pgsql://redmine@localhost:5432/redmine {1005C30EE3}>
2020-09-26T00:06:06.903000+01:00 WARNING PostgreSQL warning: 識別子 "idx_24851_index_custom_fields_projects_on_custom_field_id_and_project_id" を "idx_24851_index_custom_fields_projects_on_custom_field_id_and_p" に切り詰めます
2020-09-26T00:06:07.314000+01:00 WARNING PostgreSQL warning: 識別子 "idx_24859_index_custom_fields_trackers_on_custom_field_id_and_tracker_id" を "idx_24859_index_custom_fields_trackers_on_custom_field_id_and_t" に切り詰めます
2020-09-26T00:06:13.731000+01:00 WARNING PostgreSQL warning: 識別子 "idx_25098_index_issue_relations_on_issue_from_id_and_issue_to_id" を "idx_25098_index_issue_relations_on_issue_from_id_and_issue_to_i" に切り詰めます
2020-09-26T00:06:16.631000+01:00 WARNING PostgreSQL warning: 識別子 "idx_25322_index_roles_managed_roles_on_role_id_and_managed_role_id" を "idx_25322_index_roles_managed_roles_on_role_id_and_managed_role" に切り詰めます
2020-09-26T00:06:16.902000+01:00 WARNING PostgreSQL warning: 識別子 "idx_25382_index_taggings_on_taggable_id_and_taggable_type_and_context" を "idx_25382_index_taggings_on_taggable_id_and_taggable_type_and_c" に切り詰めます
2020-09-26T00:06:20.183000+01:00 LOG report summary reset
                                table name     errors       rows      bytes      total time
------------------------------------------  ---------  ---------  ---------  --------------
                           fetch meta data          0        407                     0.326s
                            Create Schemas          0          0                     0.002s
                          Create SQL Types          0          0                     0.007s
                             Create tables          0        244                     1.217s
                            Set Table OIDs          0        122                     0.008s
------------------------------------------  ---------  ---------  ---------  --------------
                     public.arch_decisions          0          0                     0.064s
              public.arch_decision_factors          0          0                     0.126s
                public.acceptance_criteria          0          0                     0.048s
             public.arch_decision_statuses          0          7     0.2 kB          0.242s
          public.arch_decision_discussions          0          0                     0.122s
               public.arch_decision_issues          0          0                     0.254s
                       public.auth_sources          0          0                     0.347s
               public.burndown_data_points          0          0                     0.481s
                        public.attachments          0       5081   958.2 kB          0.672s
                         public.changesets          0      61043     9.8 MB          1.511s
                             public.boards          0          3     0.4 kB          0.698s
                            public.changes          0     691284    68.6 MB          7.813s
                  public.changeset_parents          0      21914   299.6 kB          1.094s
         public.chart_done_ratios_20121107          0       9030   300.9 kB          1.277s
      public.chart_issue_statuses_20121107          0       9936   378.0 kB          1.484s
    public.chart_saved_conditions_20121107          0          1     0.0 kB          1.799s
        public.chart_time_entries_20121107          0       2012    75.5 kB          1.958s
                    public.code_categories          0         24     0.5 kB          2.044s
                       public.code_reviews          0        429    70.8 kB          2.377s
       public.code_review_project_settings          0        158    17.3 kB          2.424s
                           public.comments          0          0                     2.485s
             public.custom_fields_projects          0         71     0.5 kB          2.549s
             public.custom_fields_trackers          0         77     0.4 kB          2.632s
                      public.custom_values          0      40775     1.2 MB          3.113s
                           public.diagrams          0          0                     2.928s
                          public.documents          0         43     7.3 kB          2.983s
                    public.enabled_modules          0       1062    18.8 kB          3.155s
                            public.factors          0          0                     3.306s
                       public.groups_users          0         34     0.2 kB          3.406s
             public.hudson_build_artifacts          0          0                     3.471s
          public.hudson_build_test_results          0          0                     3.552s
                        public.hudson_jobs          0          0                     3.643s
                    public.hudson_settings          0          0                     3.705s
                            public.imports          0          0                     3.747s
                       public.import_items          0          0                     3.785s
                   public.issue_categories          0        161     5.0 kB          3.774s
                     public.issue_statuses          0         11     0.2 kB          3.838s
                           public.journals          0     109869    29.3 MB          7.247s
                      public.kanban_issues          0          0                     3.002s
                      public.kb_categories          0          0                     3.393s
                       public.member_roles          0        875    12.9 kB          3.603s
                         public.milestones          0          0                     3.656s
                       public.oauth_nonces          0        411    26.3 kB          3.797s
public.open_id_authentication_associations          0          0                     3.897s
                           public.projects          0        147    22.3 kB          3.928s
                            public.queries          0        200    64.0 kB          4.049s
                            public.ratings          0          0                     4.109s
                              public.roles          0          8     4.6 kB          4.202s
                  public.schema_migrations          0        410     5.8 kB          4.266s
                     public.sprints_setups          0          0                     4.342s
                  public.changesets_issues          0      13154   165.6 kB          1.385s
                      public.story_actions          0          0                     4.452s
                         public.strategies          0          0                     4.541s
                  public.chart_done_ratios          0      16681   602.5 kB          1.770s
                               public.tags          0          4     0.0 kB          4.656s
                       public.time_entries          0       6845   613.5 kB          4.913s
               public.chart_issue_statuses          0      17604   700.4 kB          1.915s
                             public.tokens          0       1550   148.1 kB          4.961s
                              public.users          0        321    60.8 kB          5.051s
                       public.user_stories          0          0                     5.131s
                           public.viewings          0          0                     5.217s
             public.chart_saved_conditions          0          0                     1.881s
                              public.wikis          0        146     2.1 kB          5.345s
                 public.chart_time_entries          0       6266   253.0 kB          2.164s
              public.wiki_content_versions          0      19948    79.7 MB          9.140s
                public.client_applications          0          2     0.5 kB          2.093s
                     public.code_documents          0          6     3.5 kB          2.502s
            public.code_review_assignments          0          1     0.0 kB          2.590s
          public.code_review_user_settings          0          0                     2.687s
                      public.custom_fields          0         53    20.0 kB          2.706s
                public.custom_fields_roles          0          0                     2.691s
          public.custom_field_enumerations          0          0                     2.771s
                   public.deploy_histories          0          1     0.4 kB          2.705s
                     public.documentations          0          0                     2.791s
                    public.email_addresses          0        309    22.8 kB          2.786s
                       public.enumerations          0        100     4.6 kB          2.839s
                    public.factor_statuses          0          4     0.1 kB          2.811s
                      public.hudson_builds          0          0                     2.849s
            public.hudson_build_changesets          0          0                     2.815s
              public.hudson_health_reports          0          0                     2.872s
                public.hudson_job_settings          0          0                     2.876s
     public.hudson_settings_health_reports          0          0                     2.904s
               public.import_in_progresses          0          1     0.8 kB          2.923s
                             public.issues          0      18814    13.7 MB          4.372s
                    public.issue_relations          0       2983    81.5 kB          1.829s
                         public.iterations          0          0                     1.902s
                    public.journal_details          0     143331    22.9 MB          4.780s
             public.wiki_extensions_counts          0          0                     3.541s
           public.wiki_extensions_settings          0         78     3.8 kB          3.602s
      public.wiki_extensions_tag_relations          0          0                     3.679s
                         public.wiki_pages          0       1804    90.8 kB          3.771s
                          public.workflows          0       1791    77.1 kB          3.855s
                 public.work_kb_categories          0          7     0.7 kB          3.965s
                      public.work_viewings          0         14     0.6 kB          4.052s
                        public.kb_articles          0          0                     0.241s
                            public.members          0        755    25.2 kB          0.349s
                           public.messages          0         88    34.2 kB          0.501s
                               public.news          0         20     6.1 kB          0.616s
                       public.oauth_tokens          0        258    55.9 kB          0.783s
      public.open_id_authentication_nonces          0          0                     0.841s
                  public.projects_trackers          0        603     3.4 kB          0.910s
                      public.queries_roles          0          2     0.0 kB          1.000s
                       public.repositories          0         77    19.0 kB          1.072s
                public.roles_managed_roles          0          0                     1.134s
                           public.settings          0         92    11.2 kB          1.221s
                            public.stories          0          0                     1.310s
                 public.story_team_members          0          0                     1.421s
                           public.taggings          0          3     0.1 kB          1.502s
                          public.task_logs          0          0                     1.509s
                     public.time_estimates          0         12     0.6 kB          1.604s
                           public.trackers          0         11     0.3 kB          1.611s
                   public.user_preferences          0        312    47.0 kB          1.708s
                           public.versions          0        407    43.2 kB          1.653s
                           public.watchers          0       1448    28.7 kB          1.666s
                      public.wiki_contents          0       1804     6.8 MB          2.399s
           public.wiki_extensions_comments          0          0                     1.218s
              public.wiki_extensions_menus          0        470     7.7 kB          1.311s
               public.wiki_extensions_tags          0          0                     1.334s
              public.wiki_extensions_votes          0          0                     1.470s
                     public.wiki_redirects          0         59     3.6 kB          1.472s
                   public.work_kb_articles          0         15    31.1 kB          1.580s
                       public.work_ratings          0          2     0.0 kB          1.564s
------------------------------------------  ---------  ---------  ---------  --------------
                   COPY Threads Completion          0          4                    16.389s
                            Create Indexes          0        285                    32.024s
                    Index Build Completion          0        285                     0.393s
                           Reset Sequences          0        112                     0.127s
                              Primary Keys          0        112                     0.483s
                       Create Foreign Keys          0          0                     0.000s
                           Create Triggers          0          0                     0.002s
                          Install Comments          0          0                     0.000s
------------------------------------------  ---------  ---------  ---------  --------------
                         Total import time          ✓    1213332   237.3 MB         49.418s
```

インデックス名が一部切り捨てられているが、意外とすんなり成功した。
Remdmine から接続しても問題なく稼働している。

### pg_loader by Docker

[dimitri/pgloader](https://hub.docker.com/r/dimitri/pgloader/)のイメージを使用する。
ソースコードは[こちら](https://github.com/dimitri/pgloader)

移行元と移行先の設定を行う

```bash
$ cat pgloader/config.load
load database
    from mysql://redmine:redmine@localhost/redmine
    into pgsql://redmine:redmine@localhost/redmine
    alter schema 'redmine' rename to 'public';
```

以下で実行する。

```bash
$ docker run --rm --net="host" --name pgloader -v $(pwd)/config.load:/tmp/config.load dimitri/pgloader:latest pgloader --dry-run /tmp/config.load
```



## 参照先

- [RedmineのデータベースをMySQLからPostgreSQLへ移行した](https://qiita.com/ryouma_nagare/items/c4ba5298dd283333bb85)
- [yaml_dbを使ってMySQLからPostgreSQLにRedmineを移行した](https://hnron.hatenablog.com/entry/2015/08/18/012738)
- [Redmineで使うデータベースを変更する](http://blog.redmine.jp/articles/change-database/)
- [［Redmine］Redmineのマイグレーションを行う](https://daybreaksnow.hatenablog.jp/entry/2016/12/11/145403)
- [pgloader 3.4.1でMySQLからPostgreSQLへスマートに移行しよう（翻訳）](https://techracho.bpsinc.jp/hachi8833/2017_07_20/43380)
- [pgloaderでMySQL→Postgresへの移行を行う](https://qiita.com/11ohina017/items/4a808e4fc03e1ac890ba)
