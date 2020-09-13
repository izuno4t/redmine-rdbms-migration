# redmine-rdbms-migration

Redmine の RDBMS を MySQL から PostgreSQL に変更する

## 前提条件

- 対象環境の Redmine は 3.4.x
- 既存環境は MySQL 5.7
- 移行環境は PostgreSQL 12
- 現行データは1日1回 mysqldump にてダンプファイルを作成
  
## 移行手段

## プロセス

### Redmine データベースの作成

```bash
mysql -h 127.0.0.1  -u root -p < mysqldump_20200XXXXXXXXX
```

### Rails セットアップ

```bash
$ wget https://www.redmine.org/releases/redmine-3.4.5.tar.gz
$ tar zxvf redmine-3.4.5.tar.gz
$ cd redmine-3.4.5
$ cp config/database.yml.example configdatabase.yml
$ vi config
$ bundle install
```

### yaml_db

- yaml_db は移行元と移行先が同じスキーマでないとだめ
- Rails を長期間つかっていると、プライグインの追加・削除等あるため、使用していないテーブルが残った状態になっている→つまり使えない
- [PostgreSQL 10 : Each sequence does not have `increment_by` column, need to use `pg_sequences`](https://github.com/rails/rails/issues/28780)が発生するので、PostgreSQLを9.6に変更

```console
$ RAILS_ENV=production rake db:migrate
$ RAILS_ENV=production rake db:data:dump
$ vi config/database.yml
RAILS_ENV=production rake db:data:load
```

## 参照先

- [RedmineのデータベースをMySQLからPostgreSQLへ移行した](https://qiita.com/ryouma_nagare/items/c4ba5298dd283333bb85)
- [yaml_dbを使ってMySQLからPostgreSQLにRedmineを移行した](https://hnron.hatenablog.com/entry/2015/08/18/012738)
- [Redmineで使うデータベースを変更する](http://blog.redmine.jp/articles/change-database/)
- [［Redmine］Redmineのマイグレーションを行う](https://daybreaksnow.hatenablog.jp/entry/2016/12/11/145403)
- [pgloader 3.4.1でMySQLからPostgreSQLへスマートに移行しよう（翻訳）](https://techracho.bpsinc.jp/hachi8833/2017_07_20/43380)
- 