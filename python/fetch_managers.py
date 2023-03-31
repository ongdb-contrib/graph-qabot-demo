import tushare as ts
import pandas as pd
import system_constant as sys_cnt
import os
import time

# 初始化pro接口
pro = ts.pro_api(sys_cnt.tushare_token())


# 获取股票相关信息
def run():
    # 查询当前所有正常上市交易的股票列表
    data = pro.stock_basic(exchange='', list_status='L', fields='ts_code,symbol,name,area,industry,list_date')
    tss = data['ts_code']
    result = []
    ct = 0
    bk_ct = 100000
    for code in tss:
        time.sleep(0.5)
        # 获取单个公司高管全部数据
        df = pro.stk_managers(ts_code=code)
        result.append(df)
        ct += 1
        if ct > bk_ct:
            break
    df_merge = pd.concat(result)
    print(df_merge)
    df_merge.to_csv(path_or_buf=os.getcwd().replace('python', 'csv') + '\\managers.csv',
                    encoding='GBK',
                    columns=['ts_code', 'ann_date', 'name', 'gender', 'lev', 'title', 'edu', 'national', 'birthday',
                             'begin_date', 'end_date'],
                    index=False)


if __name__ == '__main__':
    run()
