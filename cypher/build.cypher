//设计索引和约束
CREATE CONSTRAINT ON (n:股票代码) ASSERT (n.value) IS NODE KEY;
CREATE CONSTRAINT ON (n:股票) ASSERT (n.value) IS NODE KEY;
CREATE CONSTRAINT ON (n:股票名称) ASSERT (n.value) IS NODE KEY;
CREATE CONSTRAINT ON (n:地域) ASSERT (n.value) IS NODE KEY;
CREATE CONSTRAINT ON (n:行业) ASSERT (n.value) IS NODE KEY;
CREATE CONSTRAINT ON (n:上市日期) ASSERT (n.value) IS NODE KEY;
CREATE CONSTRAINT ON (n:高管) ASSERT (n.md5) IS NODE KEY;
CREATE INDEX ON :高管(value);
CREATE CONSTRAINT ON (n:性别) ASSERT (n.value) IS NODE KEY;
CREATE CONSTRAINT ON (n:学历) ASSERT (n.value) IS NODE KEY;
CREATE CONSTRAINT ON (n:性别_别名) ASSERT (n.value) IS NODE KEY;

//构建数据
//将生成的CSV数据，放置在<ONGDB_HOME>/import目录下，CSV转为UTF-8-BOM格式（可以使用Notepad++转格式）
LOAD CSV WITH HEADERS FROM 'file:/stocks.csv' AS row
WITH row.ts_code AS fval,row.symbol AS tval
WHERE tval IS NOT NULL AND tval<>''
MERGE (f:股票 {value:fval})
MERGE (t:股票代码 {value:tval})
MERGE (f)-[:股票代码]->(t);

LOAD CSV WITH HEADERS FROM 'file:/stocks.csv' AS row
WITH row.ts_code AS fval,row.name AS tval
WHERE tval IS NOT NULL AND tval<>''
MERGE (f:股票 {value:fval})
MERGE (t:股票名称 {value:tval})
MERGE (f)-[:股票名称]->(t);

LOAD CSV WITH HEADERS FROM 'file:/stocks.csv' AS row
WITH row.ts_code AS fval,row.area AS tval
WHERE tval IS NOT NULL AND tval<>''
MERGE (f:股票 {value:fval})
MERGE (t:地域 {value:tval})
MERGE (f)-[:地域]->(t);

LOAD CSV WITH HEADERS FROM 'file:/stocks.csv' AS row
WITH row.ts_code AS fval,row.industry AS tval
WHERE tval IS NOT NULL AND tval<>''
MERGE (f:股票 {value:fval})
MERGE (t:行业 {value:tval})
MERGE (f)-[:所属行业]->(t);

LOAD CSV WITH HEADERS FROM 'file:/stocks.csv' AS row
WITH row.ts_code AS fval,row.list_date AS tval
WHERE tval IS NOT NULL AND tval<>''
MERGE (f:股票 {value:fval})
MERGE (t:上市日期 {value:TOINTEGER(tval)})
MERGE (f)-[:上市日期]->(t);

LOAD CSV WITH HEADERS FROM 'file:/managers.csv' AS row
WITH row,apoc.util.md5([row.name,row.gender,row.birthday]) AS fval,row.ts_code AS tval
WHERE tval IS NOT NULL AND tval<>'' AND fval IS NOT NULL AND fval<>'' AND (row.end_date IS NULL OR row.end_date='')
MERGE (f:高管 {md5:fval}) SET f+={value:row.name}
MERGE (t:股票 {value:tval})
MERGE (f)-[:任职于]->(t);

LOAD CSV WITH HEADERS FROM 'file:/managers.csv' AS row
WITH row,apoc.util.md5([row.name,row.gender,row.birthday]) AS fval,row.gender AS tval
WHERE tval IS NOT NULL AND tval<>'' AND fval IS NOT NULL AND fval<>'' AND (row.end_date IS NULL OR row.end_date='')
MERGE (f:高管 {md5:fval}) SET f+={value:row.name}
MERGE (t:性别 {value:tval})
MERGE (f)-[:性别]->(t);

LOAD CSV WITH HEADERS FROM 'file:/managers.csv' AS row
WITH row,apoc.util.md5([row.name,row.gender,row.birthday]) AS fval,row.edu AS tval
WHERE tval IS NOT NULL AND tval<>'' AND fval IS NOT NULL AND fval<>'' AND (row.end_date IS NULL OR row.end_date='')
MERGE (f:高管 {md5:fval}) SET f+={value:row.name}
MERGE (t:学历 {value:tval})
MERGE (f)-[:学历]->(t);

WITH ['女性','女'] AS list
UNWIND list AS wd
WITH wd
MATCH (n:性别) WHERE n.value='F' WITH n,wd
MERGE (t:性别_别名 {value:wd})
MERGE (n)-[:别名]->(t);

WITH ['男性','男'] AS list
UNWIND list AS wd
WITH wd
MATCH (n:性别) WHERE n.value='M' WITH n,wd
MERGE (t:性别_别名 {value:wd})
MERGE (n)-[:别名]->(t);

//配置图数据模型
CALL apoc.custom.asFunction(
'inference.search.qabot',
'RETURN \'{"graph":{"nodes":[{"properties_filter":[],"id":"1","labels":["股票代码"]},{"properties_filter":[],"id":"2","labels":["股票"]},{"properties_filter":[],"id":"3","labels":["股票名称"]},{"properties_filter":[],"id":"4","labels":["地域"]},{"properties_filter":[],"id":"5","labels":["行业"]},{"properties_filter":[],"id":"6","labels":["上市日期"]},{"properties_filter":[],"id":"7","labels":["高管"]},{"properties_filter":[],"id":"8","labels":["性别"]},{"properties_filter":[],"id":"9","labels":["学历"]},{"properties_filter":[],"id":"10","labels":["性别_别名"]}],"relationships":[{"startNode":"2","properties_filter":[],"id":"1","type":"股票代码","endNode":"1"},{"startNode":"2","properties_filter":[],"id":"2","type":"股票名称","endNode":"3"},{"startNode":"2","properties_filter":[],"id":"3","type":"地域","endNode":"4"},{"startNode":"2","properties_filter":[],"id":"4","type":"所属行业","endNode":"5"},{"startNode":"2","properties_filter":[],"id":"5","type":"上市日期","endNode":"6"},{"startNode":"7","properties_filter":[],"id":"6","type":"任职于","endNode":"2"},{"startNode":"7","properties_filter":[],"id":"7","type":"性别","endNode":"8"},{"startNode":"7","properties_filter":[],"id":"8","type":"学历","endNode":"9"},{"startNode":"8","properties_filter":[],"id":"9","type":"别名","endNode":"10"}]}}\' AS graphDataSchema',
'STRING',
NULL,
false,
'搜索时图数据扩展模式(schema)的动态获取'
);

//配置实体权重规则
CALL apoc.custom.asFunction(
'inference.weight.qabot',
'RETURN \'{"LABEL":{"股票":12,"高管":11}}\' AS weight',
'STRING',
NULL,
false,
'本体权重'
);

//配置实体搜索规则
CALL apoc.custom.asFunction(
'inference.match.qabot',
'RETURN \'{"股票名称":"value","地域":"value","上市日期":"value","性别_别名":"value","高管":"value","学历":"value","行业":"value","股票代码":"value"}\' AS nodeHitsRules',
'STRING',
NULL,
false,
'实体匹配规则'
);

//配置意图匹配规则
CALL apoc.custom.asFunction(
'inference.intended.qabot',
'RETURN \'[{"label":"上市日期","return_var_alias":"n1","sort":1,"list":["是什么时候","什么时候"],"parse_mode":"CONTAINS","order_by_field":null,"order_by_type":null},{"label":"学历","return_var_alias":"n2","sort":2,"list":["什么学历"],"parse_mode":"CONTAINS","order_by_field":null,"order_by_type":null},{"label":"高管","return_var_alias":"n3","sort":3,"list":["高管有多少位","高管都有哪些","高管有多少个"],"parse_mode":"CONTAINS","order_by_field":null,"order_by_type":null},{"label":"股票","return_var_alias":"n4","sort":4,"list":["哪些上市公司","有多少家上市公司","哪个公司","有多少家","公司有哪些","公司有多少家","股票有哪些","股票有多少支","股票有多少个","股票代码？","股票？"],"parse_mode":"CONTAINS","order_by_field":null,"order_by_type":null},{"label":"行业","return_var_alias":"n5","sort":5,"list":["什么行业","同一个行业嘛"],"parse_mode":"CONTAINS","order_by_field":null,"order_by_type":null},{"label":"股票名称","return_var_alias":"n6","sort":6,"list":["股票名称？"],"parse_mode":"CONTAINS","order_by_field":null,"order_by_type":null},{"label":"性别","return_var_alias":"n7","sort":7,"list":["性别"],"parse_mode":"OTHER","order_by_field":null,"order_by_type":null},{"label":"性别","return_var_alias":"n8","sort":8,"list":["查询性别"],"parse_mode":"EQUALS","order_by_field":null,"order_by_type":null}]\' AS intendedIntent',
'STRING',
NULL,
false,
'预期意图'
);

//配置时间页码处理等规则
CALL apoc.custom.asFunction(
'inference.parseadd.qabot',
'WITH $time AS time,$page AS page,$entityRecognitionHit AS entityRecognitionHit WITH entityRecognitionHit,REDUCE(l=\'\',e IN time.list | l+\'({var}.value>=\'+TOINTEGER(apoc.date.convertFormat(e.detail.time[0],\'yyyy-MM-dd HH:mm:ss\',\'yyyyMMdd\'))+\' AND {var}.value<=\'+TOINTEGER(apoc.date.convertFormat(e.detail.time[1],\'yyyy-MM-dd HH:mm:ss\',\'yyyyMMdd\'))+\') OR \') AS timeFilter, REDUCE(l=\'\',e IN page.list | l+\'{var}.value\'+e[0]+e[1]+\' AND \') AS pageFilter CALL apoc.case([size(timeFilter)>4,\'RETURN SUBSTRING($timeFilter,0,size($timeFilter)-4) AS timeFilter\'],\'RETURN "" AS timeFilter\',{timeFilter:timeFilter}) YIELD value WITH entityRecognitionHit,value.timeFilter AS timeFilter,pageFilter CALL apoc.case([size(pageFilter)>5,\'RETURN SUBSTRING($pageFilter,0,size($pageFilter)-5) AS pageFilter\'],\'RETURN "" AS pageFilter\',{pageFilter:pageFilter}) YIELD value WITH entityRecognitionHit,timeFilter,value.pageFilter AS pageFilter WITH entityRecognitionHit,timeFilter,pageFilter CALL apoc.case([timeFilter<>"",\'RETURN apoc.map.setPairs({},[[\\\'上市日期\\\',[{category:\\\'node\\\',labels:[\\\'上市日期\\\'],properties_filter:[{value:$timeFilter}]}]]]) AS time\'],\'RETURN {} AS time\',{timeFilter:timeFilter}) YIELD value WITH value.time AS time,pageFilter,entityRecognitionHit CALL apoc.case([pageFilter<>"",\'RETURN apoc.map.setPairs({},[[\\\'文章页数\\\',[{category:\\\'node\\\',labels:[\\\'文章页数\\\'],properties_filter:[{value:$pageFilter}]}]]]) AS page\'],\'RETURN {} AS page\',{pageFilter:pageFilter}) YIELD value WITH value.page AS page,time,entityRecognitionHit RETURN apoc.map.setKey({},\'entities\',apoc.map.merge(apoc.map.merge(entityRecognitionHit.entities,time),page)) AS entityRecognitionHit',
'MAP',
[['entityRecognitionHit','MAP'],['time','MAP'],['page','MAP']],
false,
'问答解析的内容增加到entityRecognitionHit'
);

//配置算子规则
CALL apoc.custom.asFunction(
'inference.operators.qabot',
'RETURN \'[{"keywords":["最多","最大"],"operator":{"sort": 1,"agg_operator_field": "value","agg_operator": "MAX","agg_operator_type": "NODE"}},{"keywords":["最小","最少"],"operator":{"sort": 2,"agg_operator_field": "value","agg_operator": "MIN","agg_operator_type": "NODE"}},{"keywords":["平均"],"operator":{"sort": 3,"agg_operator_field": "value","agg_operator": "AVG","agg_operator_type": "NODE"}},{"keywords":["有多少","有多少只","有多少支","多少只","多少支","多少","一共"],"operator":{"sort": 5,"agg_operator_field": "value","agg_operator": "COUNT","agg_operator_type": "NODE"}}]\' AS weight',
'STRING',
NULL,
false,
'配置算子规则'
);

//算子解析模块配置
CALL apoc.custom.asFunction(
'inference.operators.parse',
'WITH $query AS query,custom.inference.operators.qabot() AS list WITH query,apoc.convert.fromJsonList(list) AS list UNWIND list AS map WITH map,REDUCE(l=[],em IN apoc.coll.sortMaps(REDUCE(l=[],e IN map.keywords | l+{wd:e,len:LENGTH(e)}),\'len\')| l+em.wd) AS keywords,query UNWIND keywords AS keyword WITH map,keyword,query CALL apoc.case([query CONTAINS keyword,\'RETURN $keyword AS hit\'],\'RETURN \\\' \\\' AS hit\',{keyword:keyword}) YIELD value WITH map,keyword,query,REPLACE(query,value.hit,\' \') AS trim_query,value.hit AS hit WITH query,trim_query,map.operator AS operator ORDER BY map.operator.sort ASC WITH COLLECT({query:query,trim_query:trim_query,operator:operator}) AS list WITH FILTER(e IN list WHERE e.query<>e.trim_query)[0] AS map,list WITH map,list[0] AS smap CALL apoc.case([map IS NOT NULL,\'RETURN $map AS map\'],\'RETURN $smap AS map\',{map:map,smap:smap}) YIELD value WITH value.map AS map CALL apoc.case([map.trim_query=map.query,\'RETURN {} AS operator\'],\'RETURN $operator AS operator\',{trim_query:map.trim_query,operator:map.operator}) YIELD value RETURN map.query AS query,map.trim_query AS trim_query,value.operator AS operator',
'MAP',
[['query','STRING']],
false,
'算子解析'
);


//dic,dynamic,dynamic.dic
//意图配置相关词
WITH custom.inference.intended.qabot() AS str
WITH apoc.convert.fromJsonList(str) as list
UNWIND list AS map
WITH map.label AS label,map.list as list,map
WHERE UPPER(map.parse_mode)<>'CONTAINS' AND UPPER(map.parse_mode)<>'EQUALS'
WITH apoc.coll.union([label],list) as list
UNWIND list AS wd
WITH collect(DISTINCT wd) AS list
RETURN olab.nlp.userdic.add('dynamic.dic',list,true,'UTF-8') AS words;

//图数据模型相关词
WITH custom.inference.search.qabot() AS str
WITH apoc.convert.fromJsonMap(str).graph AS graph
WITH graph.relationships AS relationships,graph.nodes AS nodes
WITH REDUCE(l=[],e IN relationships | l+e.type) AS relationships,REDUCE(l=[],e IN nodes | l+e.labels[0]) AS nodes
WITH apoc.coll.union(relationships,nodes) AS list
RETURN olab.nlp.userdic.add('dynamic.dic',list,true,'UTF-8') AS words;

//实体匹配规则相关词
WITH custom.inference.match.qabot() AS str
WITH olab.map.keys(apoc.convert.fromJsonMap(str)) AS list
UNWIND list AS lb
WITH lb
WHERE lb<>'性别' AND lb<>'上市日期'
CALL apoc.cypher.run('MATCH (n:'+lb+') WHERE NOT n.value CONTAINS \' \' RETURN COLLECT(DISTINCT n.value) AS list',{}) YIELD value
WITH value.list AS list
RETURN olab.nlp.userdic.add('dynamic.dic',list,true,'UTF-8') AS words;

RETURN olab.nlp.userdic.add('dynamic.dic',['测试','胡永乐','性别'],true,'UTF-8') AS words;

RETURN olab.nlp.userdic.refresh();

//安装问答模块存储过程
//问答结果
CALL apoc.custom.asProcedure(
'qabot',
'WITH LOWER($ask) AS query WITH query,  custom.inference.search.qabot() AS graphDataSchema,  custom.inference.weight.qabot() AS weight,  custom.inference.match.qabot() AS nodeHitsRules,  custom.inference.intended.qabot() AS intendedIntent,  custom.inference.operators.parse(query) AS oper WITH oper,oper.query AS query,oper.operator AS operator,graphDataSchema,weight,nodeHitsRules,intendedIntent,  olab.nlp.timeparser(oper.query) AS time,olab.nlp.pagenum.parse(oper.query) AS page WITH oper,operator,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  olab.replace(query,REDUCE(l=[],mp IN time.list | l+{raw:mp.text,rep:\' \'})) AS query WITH oper,operator,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  olab.hanlp.standard.segment(query) AS words WITH oper,operator,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  EXTRACT(m IN FILTER(mp IN words WHERE (mp.nature STARTS WITH \'n\' AND olab.string.matchCnEn(mp.word)<>\'\') OR mp.nature=\'uw\')| m.word) AS words WITH oper,operator,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,words,  olab.entity.recognition(graphDataSchema,nodeHitsRules,NULL,\'EXACT\',words,{isMergeLabelHit:true,labelMergeDis:0.5}) AS entityRecognitionHits WITH oper,operator,graphDataSchema,weight,intendedIntent,time,page,words,entityRecognitionHits CALL olab.entity.ptmd.queue(graphDataSchema,entityRecognitionHits,weight) YIELD value WITH oper,operator,graphDataSchema,intendedIntent,time,page,words,value AS entityRecognitionHit LIMIT 1 WITH oper,operator,graphDataSchema,intendedIntent,words,custom.inference.parseadd.qabot(entityRecognitionHit,time,page).entityRecognitionHit AS entityRecognitionHit WITH oper,operator,graphDataSchema,intendedIntent,words,entityRecognitionHit,  apoc.convert.toJson(olab.intent.schema.parse(graphDataSchema,oper.query,words,intendedIntent)) AS intentSchema WHERE SIZE(apoc.convert.fromJsonList(intendedIntent))>SIZE(apoc.convert.fromJsonMap(intentSchema).graph.nodes) WITH operator,graphDataSchema,intentSchema,intendedIntent,  olab.semantic.schema(graphDataSchema,intentSchema,apoc.convert.toJson(entityRecognitionHit)) AS semantic_schema WITH olab.semantic.cypher(apoc.convert.toJson(semantic_schema),intentSchema,-1,10,{},operator) AS cypher WITH REPLACE(cypher,\'RETURN n\',\'RETURN DISTINCT n\') AS cypher CALL apoc.cypher.run(cypher,{}) YIELD value WITH value SKIP 0 LIMIT 10 WITH olab.map.keys(value) AS keys,value UNWIND keys AS key WITH apoc.map.get(value,key) AS n CALL apoc.case([apoc.coll.contains([\'NODE\'],apoc.meta.cypher.type(n)),\'WITH $n AS n,LABELS($n) AS lbs WITH lbs[0] AS label,n.value AS value RETURN label+$sml+UPPER(TOSTRING(value)) AS result\'],\'WITH $n AS n RETURN TOSTRING(n) AS result\',{n:n,sml:\'：\'}) YIELD value RETURN value.result AS result;',
'READ',
[['result','STRING']],
[['ask','STRING']],
'问答机器人'
);


//问答结果Cypher
CALL apoc.custom.asProcedure(
'qabot.cypher',
'WITH LOWER($ask) AS query WITH query,  custom.inference.search.qabot() AS graphDataSchema,  custom.inference.weight.qabot() AS weight,  custom.inference.match.qabot() AS nodeHitsRules,  custom.inference.intended.qabot() AS intendedIntent,  custom.inference.operators.parse(query) AS oper WITH oper,oper.query AS query,oper.operator AS operator,graphDataSchema,weight,nodeHitsRules,intendedIntent,  olab.nlp.timeparser(oper.query) AS time,olab.nlp.pagenum.parse(oper.query) AS page WITH oper,operator,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  olab.replace(query,REDUCE(l=[],mp IN time.list | l+{raw:mp.text,rep:\' \'})) AS query WITH oper,operator,query,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  olab.hanlp.standard.segment(query) AS words WITH oper,operator,query,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  EXTRACT(m IN FILTER(mp IN words WHERE (mp.nature STARTS WITH \'n\' AND olab.string.matchCnEn(mp.word)<>\'\') OR mp.nature=\'uw\')| m.word) AS words WITH oper,operator,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,words,  olab.entity.recognition(graphDataSchema,nodeHitsRules,NULL,\'EXACT\',words,{isMergeLabelHit:true,labelMergeDis:0.5}) AS entityRecognitionHits WITH oper,operator,graphDataSchema,weight,intendedIntent,time,page,words,entityRecognitionHits CALL olab.entity.ptmd.queue(graphDataSchema,entityRecognitionHits,weight) YIELD value WITH oper,operator,graphDataSchema,intendedIntent,time,page,words,value AS entityRecognitionHit LIMIT 1 WITH oper,operator,graphDataSchema,intendedIntent,words,custom.inference.parseadd.qabot(entityRecognitionHit,time,page).entityRecognitionHit AS entityRecognitionHit WITH operator,graphDataSchema,intendedIntent,words,entityRecognitionHit,  apoc.convert.toJson(olab.intent.schema.parse(graphDataSchema,oper.query,words,intendedIntent)) AS intentSchema WHERE SIZE(apoc.convert.fromJsonList(intendedIntent))>SIZE(apoc.convert.fromJsonMap(intentSchema).graph.nodes) WITH operator,graphDataSchema,intentSchema,intendedIntent,  olab.semantic.schema(graphDataSchema,intentSchema,apoc.convert.toJson(entityRecognitionHit)) AS semantic_schema WITH olab.semantic.cypher(apoc.convert.toJson(semantic_schema),intentSchema,-1,10,{},operator) AS cypher WITH REPLACE(cypher,\'RETURN n\',\'RETURN DISTINCT n\') AS cypher RETURN cypher;',
'READ',
[['cypher','STRING']],
[['ask','STRING']],
'问答机器人：生成查询语句'
);

//问答推理图谱
CALL apoc.custom.asProcedure(
'qabot.graph',
'WITH LOWER($ask) AS query WITH query,  custom.inference.search.qabot() AS graphDataSchema,  custom.inference.weight.qabot() AS weight,  custom.inference.match.qabot() AS nodeHitsRules,  custom.inference.intended.qabot() AS intendedIntent WITH query AS oper,query,graphDataSchema,weight,nodeHitsRules,intendedIntent,  olab.nlp.timeparser(query) AS time,olab.nlp.pagenum.parse(query) AS page WITH oper,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  olab.replace(query,REDUCE(l=[],mp IN time.list | l+{raw:mp.text,rep:\' \'})) AS query WITH oper,query,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  olab.hanlp.standard.segment(query) AS words WITH oper,query,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  EXTRACT(m IN FILTER(mp IN words WHERE (mp.nature STARTS WITH \'n\' AND olab.string.matchCnEn(mp.word)<>\'\') OR mp.nature=\'uw\')| m.word) AS words WITH oper,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,words,  olab.entity.recognition(graphDataSchema,nodeHitsRules,NULL,\'EXACT\',words,{isMergeLabelHit:true,labelMergeDis:0.5}) AS entityRecognitionHits WITH oper,graphDataSchema,weight,intendedIntent,time,page,words,entityRecognitionHits CALL olab.entity.ptmd.queue(graphDataSchema,entityRecognitionHits,weight) YIELD value WITH oper,graphDataSchema,intendedIntent,time,page,words,value AS entityRecognitionHit LIMIT 1 WITH oper,graphDataSchema,intendedIntent,words,custom.inference.parseadd.qabot(entityRecognitionHit,time,page).entityRecognitionHit AS entityRecognitionHit WITH graphDataSchema,intendedIntent,words,entityRecognitionHit,  apoc.convert.toJson(olab.intent.schema.parse(graphDataSchema,oper,words,intendedIntent)) AS intentSchema WHERE SIZE(apoc.convert.fromJsonList(intendedIntent))>SIZE(apoc.convert.fromJsonMap(intentSchema).graph.nodes) WITH graphDataSchema,intentSchema,intendedIntent,  olab.semantic.schema(graphDataSchema,intentSchema,apoc.convert.toJson(entityRecognitionHit)) AS semantic_schema WITH olab.semantic.cypher(apoc.convert.toJson(semantic_schema),\'\',-1,10,{}) AS cypher CALL apoc.cypher.run(cypher,{}) YIELD value WITH value SKIP 0 LIMIT 10 WITH value.graph AS graph UNWIND graph AS path RETURN path;',
'READ',
[['path','PATH']],
[['ask','STRING']],
'问答机器人：问答推理图谱'
);

//生成推荐问题列表
CALL apoc.custom.asProcedure(
 'qabot.recommend_list',
 'WITH LOWER($qa) AS query WITH query,query AS raw_query,  custom.inference.search.qabot() AS graphDataSchema,  custom.inference.weight.qabot() AS weight,  custom.inference.match.qabot() AS nodeHitsRules,  custom.inference.intended.qabot() AS intendedIntent,  custom.inference.operators.parse(query) AS oper WITH raw_query,oper.query AS query,oper.operator AS operator,graphDataSchema,weight,nodeHitsRules,intendedIntent,  olab.nlp.timeparser(oper.query) AS time,olab.nlp.pagenum.parse(oper.query) AS page WITH raw_query,operator,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  olab.replace(query,REDUCE(l=[],mp IN time.list | l+{raw:mp.text,rep:\' \'})) AS query WITH raw_query,operator,query,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  olab.hanlp.standard.segment(query) AS words WITH raw_query,operator,query,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,  EXTRACT(m IN FILTER(mp IN words WHERE (mp.nature STARTS WITH \'n\' AND olab.string.matchCnEn(mp.word)<>\'\') OR mp.nature=\'uw\')| m.word) AS words WITH raw_query,query,operator,graphDataSchema,weight,nodeHitsRules,intendedIntent,time,page,words,  olab.entity.recognition(graphDataSchema,nodeHitsRules,NULL,\'EXACT\',words,{isMergeLabelHit:true,labelMergeDis:0.4}) AS entityRecognitionHits WITH raw_query,query,operator,graphDataSchema,weight,intendedIntent,time,page,words,entityRecognitionHits CALL olab.entity.ptmd.queue(graphDataSchema,entityRecognitionHits,weight) YIELD value WITH raw_query,query,operator,graphDataSchema,intendedIntent,time,page,words,value AS entityRecognitionHit WITH raw_query,entityRecognitionHit.entities AS map WITH raw_query,olab.map.keys(map) AS keys,map WITH raw_query,REDUCE(l=[],key IN keys | l+{raw:key,rep:FILTER(e IN apoc.map.get(map,key,NULL,FALSE) WHERE SIZE(key)>2)[0].labels[0]}) AS reps WITH raw_query,FILTER(e IN reps WHERE e.rep IS NOT NULL) AS reps WITH raw_query,olab.replace(raw_query,reps) AS re_query WITH raw_query,re_query,olab.editDistance(raw_query,re_query) AS score WHERE score<1 AND score>0.6 RETURN DISTINCT raw_query,re_query,score ORDER BY score DESC LIMIT 10',
 'READ',
 [['raw_query','STRING'],['re_query','STRING'],['score','NUMBER']],
 [['qa','STRING']],
 '推荐问题列表：自动推荐'
);

//配置样例问答
WITH '[{"qa":"火力发电行业博士学历的男性高管有多少位？","label":"学历"},{"qa":"山西都有哪些上市公司？","label":"地域"},{"qa":"富奥股份的高管都是什么学历？","label":"学历"},{"qa":"中国宝安属于什么行业？","label":"股票"},{"qa":"建筑工程行业有多少家上市公司？","label":"行业"},{"qa":"刘卫国是哪个公司的高管？","label":"高管"},{"qa":"美丽生态上市时间是什么时候？","label":"时间"},{"qa":"山西的上市公司有多少家？","label":"地域"},{"qa":"博士学历的高管都有哪些？","label":"学历"},{"qa":"上市公司是博士学历的高管有多少个？","label":"学历"},{"qa":"刘卫国是什么学历？","label":"高管"},{"qa":"富奥股份的男性高管有多少个？","label":"高管"},{"qa":"同在火力发电行业的上市公司有哪些？","label":"行业"},{"qa":"同在火力发电行业的上市公司有多少家？","label":"行业"},{"qa":"大悦城和荣盛发展是同一个行业嘛？","label":"股票"},{"qa":"同在河北的上市公司有哪些？","label":"股票"},{"qa":"神州高铁是什么时候上市的？","label":"时间"},{"qa":"火力发电行业男性高管有多少个？","label":"高管"},{"qa":"2023年三月六日上市的股票代码？","label":"股票"},{"qa":"2023年三月六日上市的股票有哪些？","label":"股票"},{"qa":"2023年三月六日上市的股票有多少个？","label":"股票"},{"qa":"胡永乐是什么性别？","label":"性别"}]' AS list
WITH apoc.convert.fromJsonList(list) AS list
UNWIND list AS map
WITH map
MERGE (n:DEMO_QA {qa:map.qa,label:map.label});

