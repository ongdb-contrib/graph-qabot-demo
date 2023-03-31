import tushare as ts
import system_constant as sys_cnt
import os

# 初始化pro接口
pro = ts.pro_api(sys_cnt.tushare_token())


# 获取股票相关信息
def run():
    # 查询当前所有正常上市交易的股票列表
    data = pro.stock_basic(exchange='', list_status='L', fields='ts_code,symbol,name,area,industry,list_date')
    data.to_csv(path_or_buf=os.getcwd().replace('python', 'csv') + '\\stocks.csv',
              encoding='GBK',
              columns=['ts_code', 'symbol', 'name', 'area', 'industry', 'list_date'],
              index=False)


if __name__ == '__main__':
    run()
